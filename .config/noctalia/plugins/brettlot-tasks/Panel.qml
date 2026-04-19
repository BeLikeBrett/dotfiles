import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Services.UI
import qs.Widgets

Item {
  id: root

  property var pluginApi: null
  readonly property var geometryPlaceholder: panelContainer
  property real contentPreferredWidth: 440 * Style.uiScaleRatio
  property real contentPreferredHeight: 510 * Style.uiScaleRatio
  readonly property bool allowAttach: true
  anchors.fill: parent

  readonly property var mainInstance: pluginApi?.mainInstance
  property var activeTodos: []
  property var completedTodos: []
  property var deletedTodos: []
  // viewMode: 0 = active, 1 = completed, 2 = trash
  property int viewMode: 0
  property int expandedTodoId: -1
  property var subtaskCache: ({})
  property int subtaskVersion: 0
  property int pendingCompleteId: -1
  property string pendingCompleteTitle: ""
  property int editNoteId: -1
  property string editNoteText: ""
  property int editDateId: -1
  property var editDateCurrent: null

  // Watch mainInstance for changes
  Connections {
    target: mainInstance
    ignoreUnknownSignals: true
    function onTodosChanged() {
      root.reloadTodos();
    }
    function onDeletedTodosChanged() {
      root.reloadTodos();
    }
    function onSubtasksChanged() {
      root.subtaskVersion++;
    }
  }

  Component.onCompleted: {
    if (mainInstance) reloadTodos();
  }

  onMainInstanceChanged: {
    if (mainInstance) reloadTodos();
  }

  function reloadTodos() {
    if (!mainInstance) return;
    var all = mainInstance.todos || [];
    root.activeTodos = all.filter(t => t.status === "ACTIVE");
    root.completedTodos = all.filter(t => t.status === "COMPLETED");
    root.deletedTodos = mainInstance.deletedTodos || [];

    var list;
    if (root.viewMode === 0) list = root.activeTodos;
    else if (root.viewMode === 1) list = root.completedTodos;
    else list = root.deletedTodos;

    // Use a JS array property instead of ListModel to avoid int32 truncation of dueDate
    var arr = [];
    for (var i = 0; i < list.length; i++) {
      arr.push({
        todoId: list[i].id,
        todoTitle: list[i].title,
        todoPriority: list[i].priority,
        todoStatus: list[i].status,
        todoCategory: list[i].category || "",
        todoNotes: list[i].notes || "",
        todoDueDate: list[i].dueDate || 0,
        todoIsMainTaskDone: list[i].isMainTaskDone || false
      });
    }
    root.todoItems = arr;
  }

  property var todoItems: []

  onViewModeChanged: reloadTodos()

  function getPriorityColor(priority) {
    switch (priority) {
      case "HIGH": return "#f44336";
      case "MEDIUM": return Color.mPrimary;
      case "LOW": return Color.mOnSurfaceVariant;
      default: return Color.mPrimary;
    }
  }

  function formatDate(epochMs) {
    if (!epochMs || epochMs <= 0) return "";
    var d = new Date(epochMs);
    var months = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"];
    return months[d.getMonth()] + " " + d.getDate() + ", " + d.getFullYear();
  }

  function pad2(n) {
    return n < 10 ? "0" + n : "" + n;
  }

  function dateToInputString(d) {
    return d.getFullYear() + "-" + pad2(d.getMonth() + 1) + "-" + pad2(d.getDate());
  }

  function parseDateString(str) {
    // Parse YYYY-MM-DD to epoch ms (at noon local time)
    var parts = str.split("-");
    if (parts.length !== 3) return 0;
    var y = parseInt(parts[0], 10);
    var m = parseInt(parts[1], 10);
    var dd = parseInt(parts[2], 10);
    if (isNaN(y) || isNaN(m) || isNaN(dd)) return 0;
    var d = new Date(y, m - 1, dd, 12, 0, 0);
    return isNaN(d.getTime()) ? 0 : d.getTime();
  }

  function addTodo() {
    var text = newTodoInput.text.trim();
    if (!text) return;
    if (mainInstance) {
      mainInstance.addTodo(text, "medium");
      newTodoInput.text = "";
    }
  }

  function toggleExpand(todoId) {
    if (root.expandedTodoId === todoId) {
      root.expandedTodoId = -1;
    } else {
      root.expandedTodoId = todoId;
      if (mainInstance) mainInstance.fetchSubtasks(todoId);
    }
  }

  function getSubtasks(todoId) {
    if (mainInstance && mainInstance.subtaskMap && mainInstance.subtaskMap[todoId])
      return mainInstance.subtaskMap[todoId];
    return [];
  }

  Rectangle {
    id: panelContainer
    anchors.fill: parent
    color: "transparent"

    ColumnLayout {
      anchors {
        fill: parent
        margins: Style.marginM
      }
      spacing: Style.marginS

      Rectangle {
        Layout.fillWidth: true
        Layout.fillHeight: true
        color: Color.mSurfaceVariant
        radius: Style.radiusL

        ColumnLayout {
          anchors.fill: parent
          anchors.margins: Style.marginM
          spacing: Style.marginM

          // Header
          RowLayout {
            Layout.fillWidth: true
            spacing: Style.marginS

            NIcon {
              icon: "checklist"
              pointSize: Style.fontSizeM
            }

            NText {
              text: pluginApi?.tr("panel.header.title")
              font.pointSize: Style.fontSizeM
              font.weight: Font.Medium
              color: Color.mOnSurface
            }

            Item { Layout.fillWidth: true }

            // Manual refresh button — pulls the latest from the API immediately,
            // alongside the 5s auto-poll. Same code path as the polling timer.
            NIconButton {
              icon: "refresh"
              baseSize: Style.baseWidgetSize * 0.8
              customRadius: Style.iRadiusS
              onClicked: {
                if (mainInstance) mainInstance.fetchTodos();
              }
            }

            // Clear-all-trash button — only visible in the trash view, hard-deletes
            // every row in the trash. Confirms via clearTrashConfirmDialog.
            NButton {
              visible: root.viewMode === 2 && root.deletedTodos.length > 0
              text: "Clear All"
              fontSize: Style.fontSizeXS
              onClicked: clearTrashConfirmDialog.open()
            }

            NButton {
              text: root.viewMode === 1 ? "Done" : "Active"
              fontSize: Style.fontSizeXS
              onClicked: {
                // Toggle between Active(0) and Done(1). If in Trash, go to Active.
                if (root.viewMode === 2) root.viewMode = 0;
                else root.viewMode = root.viewMode === 0 ? 1 : 0;
              }
            }

            NIconButton {
              icon: "trash"
              baseSize: Style.baseWidgetSize * 0.8
              customRadius: Style.iRadiusS
              colorBg: root.viewMode === 2
                ? "#f44336"
                : (root.deletedTodos.length > 0 ? "#f44336" : Color.transparent)
              colorFg: (root.viewMode === 2 || root.deletedTodos.length > 0)
                ? "#ffffff"
                : Color.mOnSurface
              onClicked: root.viewMode = (root.viewMode === 2 ? 0 : 2)
            }
          }

          // Add task input row
          RowLayout {
            Layout.fillWidth: true
            spacing: Style.marginS
            visible: root.viewMode === 0

            NTextInput {
              id: newTodoInput
              placeholderText: pluginApi?.tr("panel.add_todo.placeholder")
              Layout.fillWidth: true
              Keys.onReturnPressed: addTodo()
            }

            NIconButton {
              icon: "plus"
              baseSize: Style.baseWidgetSize * 0.9
              customRadius: Style.iRadiusS
              onClicked: addTodo()
            }
          }

          // Task list
          ListView {
            id: todoListView
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: root.todoItems
            spacing: Style.marginM
            boundsBehavior: Flickable.StopAtBounds

            delegate: Rectangle {
              id: delegateItem
              width: ListView.view.width
              height: cardColumn.implicitHeight
              color: cardMouse.containsMouse ? Color.mHover : Color.mSurface
              radius: Style.iRadiusM

              required property int index
              required property var modelData
              readonly property int todoId: modelData.todoId
              readonly property string todoTitle: modelData.todoTitle
              readonly property string todoPriority: modelData.todoPriority
              readonly property string todoStatus: modelData.todoStatus
              readonly property string todoCategory: modelData.todoCategory
              readonly property string todoNotes: modelData.todoNotes
              readonly property var todoDueDate: modelData.todoDueDate
              readonly property bool isMainTaskDone: modelData.todoIsMainTaskDone

              readonly property bool isExpanded: root.expandedTodoId === delegateItem.todoId
              readonly property var mySubtasks: {
                var _v = root.subtaskVersion;
                return root.getSubtasks(delegateItem.todoId);
              }
              // Matches the phone app: "all done" requires the main task circle to
              // be ticked AND every subtask completed (or no subtasks at all).
              readonly property bool allDone: {
                if (!delegateItem.isMainTaskDone) return false;
                var subs = delegateItem.mySubtasks;
                if (!subs || subs.length === 0) return true;
                for (var i = 0; i < subs.length; i++) {
                  if (!subs[i].isCompleted) return false;
                }
                return true;
              }
              readonly property bool isActive: delegateItem.todoStatus === "ACTIVE"
              readonly property bool isCompleted: delegateItem.todoStatus === "COMPLETED"
              readonly property bool isDeleted: delegateItem.todoStatus === "DELETED"

              Column {
                id: cardColumn
                width: parent.width

                // Main task row
                RowLayout {
                  id: contentRow
                  width: parent.width
                  spacing: Style.marginS

                  // Main-task-done circle (left side, mirrors the phone app).
                  // Toggles `isMainTaskDone`. Turns green with a checkmark when set.
                  Rectangle {
                    visible: delegateItem.isActive
                    Layout.preferredWidth: 22
                    Layout.preferredHeight: 22
                    Layout.leftMargin: Style.marginM
                    Layout.alignment: Qt.AlignVCenter
                    radius: 11
                    color: delegateItem.isMainTaskDone ? "#4CAF50" : "transparent"
                    border.color: delegateItem.isMainTaskDone ? "#4CAF50" : Color.mOutline
                    border.width: 2

                    NIcon {
                      anchors.centerIn: parent
                      icon: "check"
                      pointSize: Style.fontSizeXS
                      color: "#ffffff"
                      visible: delegateItem.isMainTaskDone
                    }

                    MouseArea {
                      anchors.fill: parent
                      cursorShape: Qt.PointingHandCursor
                      onClicked: {
                        if (mainInstance) {
                          mainInstance.toggleMainTask(delegateItem.todoId, delegateItem.isMainTaskDone);
                        }
                      }
                    }
                  }

                  // Priority indicator bar - green when all done
                  Rectangle {
                    Layout.preferredWidth: 4
                    Layout.fillHeight: true
                    Layout.leftMargin: delegateItem.isActive ? 0 : Style.marginM
                    Layout.topMargin: Style.marginS
                    Layout.bottomMargin: Style.marginS
                    radius: 2
                    color: {
                      if (delegateItem.isCompleted) return "#4CAF50";
                      if (delegateItem.allDone) return "#4CAF50";
                      return getPriorityColor(delegateItem.todoPriority);
                    }
                  }

                  // Title + notes + date column.
                  // TapHandler toggles the subtask view (active tasks only).
                  ColumnLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: Style.marginS
                    Layout.bottomMargin: Style.marginS
                    spacing: 2

                    TapHandler {
                      gesturePolicy: TapHandler.ReleaseWithinBounds
                      onTapped: {
                        if (delegateItem.isActive) {
                          root.toggleExpand(delegateItem.todoId);
                        }
                      }
                    }

                    NText {
                      Layout.fillWidth: true
                      text: delegateItem.todoTitle
                      color: delegateItem.isCompleted ? Color.mOnSurfaceVariant : Color.mOnSurface
                      font.strikeout: delegateItem.isCompleted
                      elide: Text.ElideRight
                      maximumLineCount: 2
                      wrapMode: Text.WordWrap
                    }

                    // Notes preview
                    NText {
                      Layout.fillWidth: true
                      visible: delegateItem.todoNotes !== ""
                      text: delegateItem.todoNotes
                      font.pointSize: Style.fontSizeXS
                      color: Color.mOnSurfaceVariant
                      elide: Text.ElideRight
                      maximumLineCount: 2
                      wrapMode: Text.WordWrap
                    }

                    // Due date
                    RowLayout {
                      visible: delegateItem.todoDueDate > 0
                      spacing: 4

                      NIcon {
                        icon: "calendar"
                        pointSize: Style.fontSizeXS
                        color: {
                          if (delegateItem.todoDueDate > 0 && delegateItem.todoDueDate < Date.now())
                            return "#f44336";
                          return Color.mOnSurfaceVariant;
                        }
                      }

                      NText {
                        text: root.formatDate(delegateItem.todoDueDate)
                        font.pointSize: Style.fontSizeXS
                        color: {
                          if (delegateItem.todoDueDate > 0 && delegateItem.todoDueDate < Date.now())
                            return "#f44336";
                          return Color.mOnSurfaceVariant;
                        }
                      }
                    }
                  }

                  // Complete checkmark (active tasks only)
                  Rectangle {
                    visible: delegateItem.isActive
                    Layout.preferredWidth: 24
                    Layout.preferredHeight: 24
                    radius: 12
                    color: delegateItem.allDone ? "#4CAF50" : "transparent"
                    border.color: delegateItem.allDone ? "#4CAF50" : Color.mOutline
                    border.width: 2

                    NIcon {
                      anchors.centerIn: parent
                      icon: "check"
                      pointSize: Style.fontSizeXS
                      color: delegateItem.allDone ? "#ffffff" : Color.mOutline
                    }

                    MouseArea {
                      anchors.fill: parent
                      cursorShape: delegateItem.allDone ? Qt.PointingHandCursor : Qt.ArrowCursor
                      onClicked: {
                        if (delegateItem.allDone) {
                          root.pendingCompleteId = delegateItem.todoId;
                          root.pendingCompleteTitle = delegateItem.todoTitle;
                          confirmDialog.open();
                        }
                      }
                    }
                  }

                  // Reactivate button (completed tasks)
                  NIconButton {
                    visible: delegateItem.isCompleted
                    icon: "restore"
                    baseSize: Style.baseWidgetSize * 0.7
                    customRadius: Style.iRadiusS
                    onClicked: {
                      if (mainInstance)
                        mainInstance.toggleTodo(delegateItem.todoId, delegateItem.todoStatus);
                    }
                  }

                  // Restore button (trash items)
                  NIconButton {
                    visible: delegateItem.isDeleted
                    icon: "restore"
                    baseSize: Style.baseWidgetSize * 0.7
                    customRadius: Style.iRadiusS
                    onClicked: {
                      if (mainInstance) mainInstance.restoreTodo(delegateItem.todoId);
                    }
                  }

                  // Delete / permanent delete button
                  NIconButton {
                    icon: "trash"
                    baseSize: Style.baseWidgetSize * 0.7
                    customRadius: Style.iRadiusS
                    Layout.rightMargin: Style.marginS
                    onClicked: {
                      if (!mainInstance) return;
                      if (delegateItem.isDeleted) {
                        mainInstance.permanentlyDelete(delegateItem.todoId);
                      } else {
                        mainInstance.deleteTodo(delegateItem.todoId);
                      }
                    }
                  }
                }

                // Subtask section (expanded)
                Column {
                  id: subtaskSection
                  width: parent.width
                  visible: delegateItem.isExpanded && delegateItem.isActive
                  leftPadding: 36
                  rightPadding: Style.marginM
                  bottomPadding: Style.marginS

                  Repeater {
                    model: delegateItem.mySubtasks

                    RowLayout {
                      width: subtaskSection.width - subtaskSection.leftPadding - subtaskSection.rightPadding
                      spacing: Style.marginS

                      Rectangle {
                        Layout.preferredWidth: 16
                        Layout.preferredHeight: 16
                        radius: 3
                        color: "transparent"
                        border.color: modelData.isCompleted ? Color.mPrimary : Color.mOutline
                        border.width: 1.5

                        Rectangle {
                          anchors.centerIn: parent
                          width: 8
                          height: 8
                          radius: 2
                          color: Color.mPrimary
                          visible: modelData.isCompleted
                        }

                        MouseArea {
                          anchors.fill: parent
                          cursorShape: Qt.PointingHandCursor
                          onClicked: {
                            if (mainInstance)
                              mainInstance.toggleSubtask(modelData.id, modelData.isCompleted, delegateItem.todoId);
                          }
                        }
                      }

                      NText {
                        Layout.fillWidth: true
                        text: modelData.title
                        font.pointSize: Style.fontSizeS
                        color: modelData.isCompleted ? Color.mOnSurfaceVariant : Color.mOnSurface
                        font.strikeout: modelData.isCompleted
                        elide: Text.ElideRight
                      }

                      NIconButton {
                        icon: "x"
                        baseSize: Style.baseWidgetSize * 0.5
                        customRadius: Style.iRadiusS
                        onClicked: {
                          if (mainInstance)
                            mainInstance.deleteSubtask(modelData.id, delegateItem.todoId);
                        }
                      }
                    }
                  }

                  // Add subtask input
                  RowLayout {
                    width: subtaskSection.width - subtaskSection.leftPadding - subtaskSection.rightPadding
                    spacing: Style.marginS

                    NTextInput {
                      id: subtaskInput
                      placeholderText: "Add step..."
                      Layout.fillWidth: true
                      Keys.onReturnPressed: {
                        var t = subtaskInput.text.trim();
                        if (t && mainInstance) {
                          mainInstance.addSubtask(delegateItem.todoId, t);
                          subtaskInput.text = "";
                        }
                      }
                    }

                    NIconButton {
                      icon: "plus"
                      baseSize: Style.baseWidgetSize * 0.6
                      customRadius: Style.iRadiusS
                      onClicked: {
                        var t = subtaskInput.text.trim();
                        if (t && mainInstance) {
                          mainInstance.addSubtask(delegateItem.todoId, t);
                          subtaskInput.text = "";
                        }
                      }
                    }
                  }
                }
              }

              // Right-click + hover handler
              MouseArea {
                id: cardMouse
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.RightButton
                onClicked: function(mouse) {
                  if (mouse.button === Qt.RightButton) {
                    taskContextMenu.taskId = delegateItem.todoId;
                    taskContextMenu.taskNotes = delegateItem.todoNotes;
                    taskContextMenu.taskDueDate = delegateItem.todoDueDate;
                    taskContextMenu.popup();
                  }
                }
              }
            }

            // Empty state
            Item {
              anchors.centerIn: parent
              visible: root.todoItems.length === 0

              NText {
                anchors.centerIn: parent
                text: {
                  if (root.viewMode === 0) return "No active tasks";
                  if (root.viewMode === 1) return "No completed tasks";
                  return "Trash is empty";
                }
                color: Color.mOnSurfaceVariant
                font.pointSize: Style.fontSizeM
              }
            }
          }
        }
      }
    }
  }

  // Right-click context menu for tasks
  Menu {
    id: taskContextMenu
    property int taskId: -1
    property string taskNotes: ""
    property int taskDueDate: 0

    MenuItem {
      text: "Edit Note"
      onTriggered: {
        root.editNoteId = taskContextMenu.taskId;
        root.editNoteText = taskContextMenu.taskNotes;
        noteEditArea.text = taskContextMenu.taskNotes;
        noteEditDialog.open();
      }
    }
    MenuItem {
      text: taskContextMenu.taskDueDate > 0 ? "Change Date" : "Set Date"
      onTriggered: {
        root.editDateId = taskContextMenu.taskId;
        root.editDateCurrent = taskContextMenu.taskDueDate > 0 ? taskContextMenu.taskDueDate : null;
        if (taskContextMenu.taskDueDate > 0) {
          dateInput.text = root.dateToInputString(new Date(taskContextMenu.taskDueDate));
        } else {
          dateInput.text = "";
        }
        dateEditDialog.open();
      }
    }
    MenuItem {
      visible: taskContextMenu.taskDueDate > 0
      text: "Clear Date"
      onTriggered: {
        if (mainInstance)
          mainInstance.updateTodoDueDate(taskContextMenu.taskId, null);
      }
    }
  }

  // Confirmation dialog for completing a task
  Popup {
    id: confirmDialog
    anchors.centerIn: parent
    width: 280 * Style.uiScaleRatio
    height: confirmColumn.implicitHeight + Style.marginM * 2
    modal: true

    background: Rectangle {
      color: Color.mSurface
      radius: Style.radiusL
      border.color: Color.mOutline
      border.width: 1
    }

    ColumnLayout {
      id: confirmColumn
      anchors.fill: parent
      anchors.margins: Style.marginM
      spacing: Style.marginM

      NText {
        Layout.fillWidth: true
        text: "Mark as complete?"
        font.pointSize: Style.fontSizeM
        font.weight: Font.Medium
        color: Color.mOnSurface
      }

      NText {
        Layout.fillWidth: true
        text: root.pendingCompleteTitle
        font.pointSize: Style.fontSizeS
        color: Color.mOnSurfaceVariant
        elide: Text.ElideRight
        maximumLineCount: 2
        wrapMode: Text.WordWrap
      }

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginM
        Item { Layout.fillWidth: true }

        NButton {
          text: "Cancel"
          fontSize: Style.fontSizeS
          onClicked: confirmDialog.close()
        }
        NButton {
          text: "Complete"
          fontSize: Style.fontSizeS
          onClicked: {
            if (mainInstance && root.pendingCompleteId > 0)
              mainInstance.toggleTodo(root.pendingCompleteId, "ACTIVE");
            confirmDialog.close();
          }
        }
      }
    }
  }

  // Confirmation dialog for clearing the trash
  Popup {
    id: clearTrashConfirmDialog
    anchors.centerIn: parent
    width: 300 * Style.uiScaleRatio
    height: clearTrashCol.implicitHeight + Style.marginM * 2
    modal: true

    background: Rectangle {
      color: Color.mSurface
      radius: Style.radiusL
      border.color: Color.mOutline
      border.width: 1
    }

    ColumnLayout {
      id: clearTrashCol
      anchors.fill: parent
      anchors.margins: Style.marginM
      spacing: Style.marginM

      NText {
        Layout.fillWidth: true
        text: "Empty trash?"
        font.pointSize: Style.fontSizeM
        font.weight: Font.Medium
        color: Color.mOnSurface
      }

      NText {
        Layout.fillWidth: true
        text: "Permanently delete all " + root.deletedTodos.length + " task(s) in the trash. This cannot be undone."
        font.pointSize: Style.fontSizeS
        color: Color.mOnSurfaceVariant
        wrapMode: Text.WordWrap
      }

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginM
        Item { Layout.fillWidth: true }

        NButton {
          text: "Cancel"
          fontSize: Style.fontSizeS
          onClicked: clearTrashConfirmDialog.close()
        }
        NButton {
          text: "Delete All"
          fontSize: Style.fontSizeS
          onClicked: {
            if (mainInstance) mainInstance.clearAllTrash();
            clearTrashConfirmDialog.close();
          }
        }
      }
    }
  }

  // Note editing dialog
  Popup {
    id: noteEditDialog
    anchors.centerIn: parent
    width: 300 * Style.uiScaleRatio
    height: noteEditCol.implicitHeight + Style.marginM * 2
    modal: true

    background: Rectangle {
      color: Color.mSurface
      radius: Style.radiusL
      border.color: Color.mOutline
      border.width: 1
    }

    ColumnLayout {
      id: noteEditCol
      anchors.fill: parent
      anchors.margins: Style.marginM
      spacing: Style.marginM

      NText {
        text: "Edit Note"
        font.pointSize: Style.fontSizeM
        font.weight: Font.Medium
        color: Color.mOnSurface
      }

      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 80
        color: Color.mSurfaceVariant
        radius: Style.iRadiusS
        border.color: Color.mOutline
        border.width: 1

        ScrollView {
          anchors.fill: parent
          anchors.margins: 4

          TextArea {
            id: noteEditArea
            wrapMode: Text.WordWrap
            color: Color.mOnSurface
            placeholderText: "Add a note..."
            placeholderTextColor: Color.mOnSurfaceVariant
            background: null
          }
        }
      }

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginM
        Item { Layout.fillWidth: true }

        NButton {
          text: "Cancel"
          fontSize: Style.fontSizeS
          onClicked: noteEditDialog.close()
        }
        NButton {
          text: "Save"
          fontSize: Style.fontSizeS
          onClicked: {
            if (mainInstance && root.editNoteId > 0)
              mainInstance.updateTodoNotes(root.editNoteId, noteEditArea.text);
            noteEditDialog.close();
          }
        }
      }
    }
  }

  // Date editing dialog
  Popup {
    id: dateEditDialog
    anchors.centerIn: parent
    width: 300 * Style.uiScaleRatio
    height: dateEditCol.implicitHeight + Style.marginM * 2
    modal: true

    background: Rectangle {
      color: Color.mSurface
      radius: Style.radiusL
      border.color: Color.mOutline
      border.width: 1
    }

    ColumnLayout {
      id: dateEditCol
      anchors.fill: parent
      anchors.margins: Style.marginM
      spacing: Style.marginM

      NText {
        text: "Set Due Date"
        font.pointSize: Style.fontSizeM
        font.weight: Font.Medium
        color: Color.mOnSurface
      }

      // Quick date buttons
      RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginS

        NButton {
          text: "Today"
          fontSize: Style.fontSizeXS
          onClicked: dateInput.text = root.dateToInputString(new Date())
        }
        NButton {
          text: "Tomorrow"
          fontSize: Style.fontSizeXS
          onClicked: {
            var d = new Date();
            d.setDate(d.getDate() + 1);
            dateInput.text = root.dateToInputString(d);
          }
        }
        NButton {
          text: "+1 Week"
          fontSize: Style.fontSizeXS
          onClicked: {
            var d = new Date();
            d.setDate(d.getDate() + 7);
            dateInput.text = root.dateToInputString(d);
          }
        }
      }

      NTextInput {
        id: dateInput
        Layout.fillWidth: true
        placeholderText: "YYYY-MM-DD"
      }

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginM
        Item { Layout.fillWidth: true }

        NButton {
          text: "Cancel"
          fontSize: Style.fontSizeS
          onClicked: dateEditDialog.close()
        }
        NButton {
          text: "Save"
          fontSize: Style.fontSizeS
          onClicked: {
            if (mainInstance && root.editDateId > 0) {
              var epoch = root.parseDateString(dateInput.text);
              if (epoch > 0) {
                mainInstance.updateTodoDueDate(root.editDateId, epoch);
              }
            }
            dateEditDialog.close();
          }
        }
      }
    }
  }
}
