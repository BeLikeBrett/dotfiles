import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.UI

Item {
  id: root
  property var pluginApi: null
  property var todos: []
  property var deletedTodos: []
  property int activeCount: 0
  property int completedCount: 0
  property bool syncing: false
  property var subtaskMap: ({})
  signal subtasksChanged()

  readonly property string serverUrl: pluginApi?.pluginSettings?.serverUrl ?? "http://localhost:8990"
  readonly property string apiKey: pluginApi?.pluginSettings?.apiKey ?? "brettlot-dev-key"
  // Polls the API every N seconds for changes made elsewhere (phone, other clients).
  // 5s = ~5s worst-case lag from a phone push to the plugin updating. Loopback HTTP +
  // tiny SQLite read = imperceptible CPU/network cost. See SYNC_GUIDE.md for the math.
  readonly property int pollInterval: (pluginApi?.pluginSettings?.pollIntervalSec ?? 5) * 1000

  // Sync timer
  Timer {
    id: syncTimer
    interval: root.pollInterval
    repeat: true
    running: true
    onTriggered: root.fetchTodos()
  }

  Component.onCompleted: {
    if (pluginApi) {
      fetchTodos();
      fetchDeletedTodos();
    }
  }

  // ============================================
  // API Communication via Process + curl
  // ============================================

  // Fetch all non-deleted todos
  Process {
    id: fetchProcess
    running: false
    stdout: SplitParser {
      onRead: data => {
        try {
          var parsed = JSON.parse(data);
          if (Array.isArray(parsed)) {
            root.todos = parsed;
            root.activeCount = parsed.filter(t => t.status === "ACTIVE").length;
            root.completedCount = parsed.filter(t => t.status === "COMPLETED").length;
            // Update plugin settings for bar widget
            if (root.pluginApi) {
              root.pluginApi.pluginSettings.activeCount = root.activeCount;
              root.pluginApi.pluginSettings.completedCount = root.completedCount;
              root.pluginApi.saveSettings();
            }
          }
        } catch (e) {
          Logger.e("BrettLoT", "Parse error: " + e);
        }
        root.syncing = false;
      }
    }
    onExited: code => {
      if (code !== 0) {
        root.syncing = false;
      }
    }
  }

  // Generic process for POST/PATCH/DELETE operations
  Process {
    id: mutateProcess
    running: false
    onExited: code => {
      // If we're in the middle of a batch (clearAllTrash), drain the next item
      // before refreshing — keeps refreshes off the per-item path.
      if (root._pendingDeleteIds.length > 0) {
        Qt.callLater(_drainPendingDeletes);
      } else {
        Qt.callLater(root.fetchTodos);
        Qt.callLater(root.fetchDeletedTodos);
      }
    }
  }

  // Fetch deleted (trashed) todos
  Process {
    id: deletedFetchProcess
    running: false
    stdout: SplitParser {
      onRead: data => {
        try {
          var parsed = JSON.parse(data);
          if (Array.isArray(parsed)) {
            root.deletedTodos = parsed;
          }
        } catch (e) {
          Logger.e("BrettLoT", "Deleted parse error: " + e);
        }
      }
    }
  }

  function fetchDeletedTodos() {
    if (deletedFetchProcess.running) return;
    deletedFetchProcess.command = [
      "curl", "-sf",
      "-H", "X-API-Key: " + apiKey,
      serverUrl + "/api/todos?status=DELETED"
    ];
    deletedFetchProcess.running = true;
  }

  function fetchTodos() {
    if (fetchProcess.running) return;
    root.syncing = true;
    fetchProcess.command = [
      "curl", "-sf",
      "-H", "X-API-Key: " + apiKey,
      serverUrl + "/api/todos"
    ];
    fetchProcess.running = true;
  }

  function addTodo(title, priority) {
    if (!title || !title.trim()) {
      ToastService.showError(pluginApi.tr("main.error_empty_title"));
      return;
    }
    var body = JSON.stringify({
      title: title.trim(),
      priority: priority.toUpperCase()
    });
    mutateProcess.command = [
      "curl", "-sf",
      "-X", "POST",
      "-H", "X-API-Key: " + apiKey,
      "-H", "Content-Type: application/json",
      "-d", body,
      serverUrl + "/api/todos"
    ];
    mutateProcess.running = true;
    ToastService.showNotice(pluginApi.tr("main.added_task"));
  }

  function toggleTodo(todoId, currentStatus) {
    var newStatus = currentStatus === "ACTIVE" ? "COMPLETED" : "ACTIVE";
    var body = JSON.stringify({ status: newStatus });
    mutateProcess.command = [
      "curl", "-sf",
      "-X", "PATCH",
      "-H", "X-API-Key: " + apiKey,
      "-H", "Content-Type: application/json",
      "-d", body,
      serverUrl + "/api/todos/" + todoId
    ];
    mutateProcess.running = true;
    if (newStatus === "COMPLETED") {
      ToastService.showNotice(pluginApi.tr("main.completed_task"));
    } else {
      ToastService.showNotice(pluginApi.tr("main.reactivated_task"));
    }
  }

  function deleteTodo(todoId) {
    // Soft-delete: PATCH status=DELETED so it goes to Trash
    var body = JSON.stringify({ status: "DELETED" });
    mutateProcess.command = [
      "curl", "-sf",
      "-X", "PATCH",
      "-H", "X-API-Key: " + apiKey,
      "-H", "Content-Type: application/json",
      "-d", body,
      serverUrl + "/api/todos/" + todoId
    ];
    mutateProcess.running = true;
    ToastService.showNotice(pluginApi.tr("main.deleted_task"));
  }

  function restoreTodo(todoId) {
    var body = JSON.stringify({ status: "ACTIVE" });
    mutateProcess.command = [
      "curl", "-sf",
      "-X", "PATCH",
      "-H", "X-API-Key: " + apiKey,
      "-H", "Content-Type: application/json",
      "-d", body,
      serverUrl + "/api/todos/" + todoId
    ];
    mutateProcess.running = true;
  }

  function permanentlyDelete(todoId) {
    mutateProcess.command = [
      "curl", "-sf",
      "-X", "DELETE",
      "-H", "X-API-Key: " + apiKey,
      serverUrl + "/api/todos/" + todoId
    ];
    mutateProcess.running = true;
  }

  /**
   * Hard-deletes every todo currently in the trash. Drains a queue of remoteIds
   * via the existing mutateProcess (one at a time, since Process only runs one
   * command at a time). The onExited handler drains the queue on each tick.
   */
  property var _pendingDeleteIds: []

  function clearAllTrash() {
    var deleted = root.deletedTodos || [];
    if (deleted.length === 0) return;
    var queue = [];
    for (var i = 0; i < deleted.length; i++) queue.push(deleted[i].id);
    root._pendingDeleteIds = queue;
    ToastService.showNotice("Clearing trash...");
    _drainPendingDeletes();
  }

  function _drainPendingDeletes() {
    if (root._pendingDeleteIds.length === 0) return;
    if (mutateProcess.running) {
      Qt.callLater(_drainPendingDeletes);
      return;
    }
    var queue = root._pendingDeleteIds.slice();
    var todoId = queue.shift();
    root._pendingDeleteIds = queue;
    mutateProcess.command = [
      "curl", "-sf",
      "-X", "DELETE",
      "-H", "X-API-Key: " + apiKey,
      serverUrl + "/api/todos/" + todoId
    ];
    mutateProcess.running = true;
  }

  function clearCompleted() {
    var completed = root.todos.filter(t => t.status === "COMPLETED");
    for (var i = 0; i < completed.length; i++) {
      deleteTodo(completed[i].id);
    }
    if (completed.length > 0) {
      ToastService.showNotice(pluginApi.tr("main.cleared_completed"));
    }
  }

  function toggleMainTask(todoId, currentValue) {
    var body = JSON.stringify({ isMainTaskDone: !currentValue });
    mutateProcess.command = [
      "curl", "-sf",
      "-X", "PATCH",
      "-H", "X-API-Key: " + apiKey,
      "-H", "Content-Type: application/json",
      "-d", body,
      serverUrl + "/api/todos/" + todoId
    ];
    mutateProcess.running = true;
  }

  function updateTodoNotes(todoId, notes) {
    var body = JSON.stringify({ notes: notes });
    mutateProcess.command = [
      "curl", "-sf",
      "-X", "PATCH",
      "-H", "X-API-Key: " + apiKey,
      "-H", "Content-Type: application/json",
      "-d", body,
      serverUrl + "/api/todos/" + todoId
    ];
    mutateProcess.running = true;
  }

  function updateTodoDueDate(todoId, dueDate) {
    var body = JSON.stringify({ dueDate: dueDate });
    mutateProcess.command = [
      "curl", "-sf",
      "-X", "PATCH",
      "-H", "X-API-Key: " + apiKey,
      "-H", "Content-Type: application/json",
      "-d", body,
      serverUrl + "/api/todos/" + todoId
    ];
    mutateProcess.running = true;
  }

  // Subtask operations
  property int _pendingSubtaskTodoId: -1

  Process {
    id: subtaskFetchProcess
    running: false
    stdout: SplitParser {
      onRead: data => {
        try {
          var parsed = JSON.parse(data);
          if (Array.isArray(parsed)) {
            var newMap = Object.assign({}, root.subtaskMap);
            newMap[root._pendingSubtaskTodoId] = parsed;
            root.subtaskMap = newMap;
            root.subtasksChanged();
          }
        } catch (e) {
          Logger.e("BrettLoT", "Subtask parse error: " + e);
        }
      }
    }
  }

  Process {
    id: subtaskMutateProcess
    running: false
    property int todoIdToRefresh: -1
    onExited: code => {
      if (subtaskMutateProcess.todoIdToRefresh > 0) {
        Qt.callLater(() => root.fetchSubtasks(subtaskMutateProcess.todoIdToRefresh));
      }
    }
  }

  function fetchSubtasks(todoId) {
    if (subtaskFetchProcess.running) return;
    root._pendingSubtaskTodoId = todoId;
    subtaskFetchProcess.command = [
      "curl", "-sf",
      "-H", "X-API-Key: " + apiKey,
      serverUrl + "/api/todos/" + todoId + "/subtasks"
    ];
    subtaskFetchProcess.running = true;
  }

  function addSubtask(todoId, title) {
    if (!title || !title.trim()) return;
    var body = JSON.stringify({
      title: title.trim(),
      sortOrder: 0
    });
    subtaskMutateProcess.todoIdToRefresh = todoId;
    subtaskMutateProcess.command = [
      "curl", "-sf",
      "-X", "POST",
      "-H", "X-API-Key: " + apiKey,
      "-H", "Content-Type: application/json",
      "-d", body,
      serverUrl + "/api/todos/" + todoId + "/subtasks"
    ];
    subtaskMutateProcess.running = true;
  }

  function toggleSubtask(subtaskId, isCompleted, todoId) {
    var body = JSON.stringify({ isCompleted: !isCompleted });
    subtaskMutateProcess.todoIdToRefresh = todoId;
    subtaskMutateProcess.command = [
      "curl", "-sf",
      "-X", "PATCH",
      "-H", "X-API-Key: " + apiKey,
      "-H", "Content-Type: application/json",
      "-d", body,
      serverUrl + "/api/subtasks/" + subtaskId
    ];
    subtaskMutateProcess.running = true;
  }

  function deleteSubtask(subtaskId, todoId) {
    subtaskMutateProcess.todoIdToRefresh = todoId;
    subtaskMutateProcess.command = [
      "curl", "-sf",
      "-X", "DELETE",
      "-H", "X-API-Key: " + apiKey,
      serverUrl + "/api/subtasks/" + subtaskId
    ];
    subtaskMutateProcess.running = true;
  }

  // IPC handlers
  IpcHandler {
    target: "plugin:brettlot-tasks"

    function togglePanel() {
      if (!pluginApi) return;
      pluginApi.withCurrentScreen(screen => {
        pluginApi.togglePanel(screen);
      });
    }

    function refresh() {
      root.fetchTodos();
    }

    function add(title: string, priority: string) {
      root.addTodo(title, priority || "medium");
    }

    function getCount(): string {
      return JSON.stringify({
        active: root.activeCount,
        completed: root.completedCount,
        total: root.todos.length
      });
    }
  }
}
