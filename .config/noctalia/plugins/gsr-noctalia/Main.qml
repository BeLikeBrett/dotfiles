import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.UI
import qs.Services.System
import qs.Services.Compositor

Item {
    id: root

    property var pluginApi: null

    property bool isRecording: false
    property bool isPending: false
    property bool hasActiveRecording: false
    property string outputPath: ""
    property bool isAvailable: false
    property string detectedMonitor: ""
    property bool usePrimeRun: false

    // Replay state
    property bool isReplaying: false
    property bool isReplayPending: false

    // Cached audio device / app lists (id|name per line)
    property var audioDevicesCache: []
    property var audioAppsCache: []

    Process {
        id: checker
        running: true
        command: ["sh", "-c", "command -v gpu-screen-recorder >/dev/null 2>&1 || (command -v flatpak >/dev/null 2>&1 && flatpak list --app | grep -q 'com.dec05eba.gpu_screen_recorder')"]

        onExited: function (exitCode) {
            isAvailable = (exitCode === 0);
            running = false;
            if (isAvailable) {
                refreshAudioDevices();
                // If 24/7 replay mode is enabled, kick off the buffer automatically
                if (replayEnabled && replayAlwaysOn) {
                    alwaysOnStartTimer.start();
                }
            }
        }

        stdout: StdioCollector {}
        stderr: StdioCollector {}
    }

    // ── Audio device / app discovery ────────────────────────────────────

    function refreshAudioDevices() {
        audioDevicesProcess.running = true;
        audioAppsProcess.running = true;
    }

    Process {
        id: audioDevicesProcess
        command: ["sh", "-c", "gpu-screen-recorder --list-audio-devices 2>/dev/null || flatpak run --command=gpu-screen-recorder com.dec05eba.gpu_screen_recorder --list-audio-devices 2>/dev/null"]
        stdout: StdioCollector {}
        onExited: function (exitCode) {
            var text = String(audioDevicesProcess.stdout.text || "");
            var out = [];
            text.split("\n").forEach(line => {
                var l = line.trim();
                if (!l) return;
                var parts = l.split("|");
                out.push({"id": parts[0], "name": parts.length > 1 ? parts[1] : parts[0]});
            });
            audioDevicesCache = out;
        }
    }

    Process {
        id: audioAppsProcess
        command: ["sh", "-c", "gpu-screen-recorder --list-application-audio 2>/dev/null || flatpak run --command=gpu-screen-recorder com.dec05eba.gpu_screen_recorder --list-application-audio 2>/dev/null"]
        stdout: StdioCollector {}
        onExited: function (exitCode) {
            var text = String(audioAppsProcess.stdout.text || "");
            var out = [];
            text.split("\n").forEach(line => {
                var l = line.trim();
                if (!l) return;
                out.push(l);
            });
            audioAppsCache = out;
        }
    }

    IpcHandler {
        target: "plugin:gsr-noctalia"

        function toggle() {
            if (root.isAvailable) {
                root.toggleRecording();
            }
        }

        function start() {
            if (root.isAvailable && !root.isRecording && !root.isPending) {
                root.startRecording();
            }
        }

        function stop() {
            if (root.isRecording || root.isPending) {
                root.stopRecording();
            }
        }

        function toggleReplay() {
            if (root.isAvailable) {
                root.toggleReplay();
            }
        }

        function startReplay() {
            if (root.isAvailable && !root.isReplaying && !root.isReplayPending) {
                root.startReplay();
            }
        }

        function stopReplay() {
            if (root.isReplaying || root.isReplayPending) {
                root.stopReplay();
            }
        }

        function saveReplay() {
            if (root.isReplaying) {
                root.saveReplay();
            }
        }
    }

    // Settings shortcuts
    readonly property bool hideInactive: pluginApi?.pluginSettings?.hideInactive ?? false
    readonly property string directory: pluginApi?.pluginSettings?.directory || ""
    readonly property string filenamePattern: pluginApi?.pluginSettings?.filenamePattern || "recording_yyyyMMdd_HHmmss"
    readonly property string frameRate: pluginApi?.pluginSettings?.frameRate || "60"
    readonly property string customFrameRate: pluginApi?.pluginSettings?.customFrameRate || "60"
    readonly property string frameRateMode: pluginApi?.pluginSettings?.frameRateMode || "vfr"
    readonly property string audioCodec: pluginApi?.pluginSettings?.audioCodec || "opus"
    readonly property string audioBitrate: pluginApi?.pluginSettings?.audioBitrate || ""
    readonly property string videoCodec: pluginApi?.pluginSettings?.videoCodec || "h264"
    readonly property string quality: pluginApi?.pluginSettings?.quality || "very_high"
    readonly property string bitrateMode: pluginApi?.pluginSettings?.bitrateMode || "auto"
    readonly property string colorRange: pluginApi?.pluginSettings?.colorRange || "limited"
    readonly property bool showCursor: pluginApi?.pluginSettings?.showCursor ?? true
    readonly property bool copyToClipboard: pluginApi?.pluginSettings?.copyToClipboard ?? false
    readonly property var audioTracks: pluginApi?.pluginSettings?.audioTracks ?? ["default_output"]
    readonly property string videoSource: pluginApi?.pluginSettings?.videoSource || "portal"
    readonly property string resolution: pluginApi?.pluginSettings?.resolution || "original"
    readonly property string container: pluginApi?.pluginSettings?.container || "mp4"
    readonly property string encoder: pluginApi?.pluginSettings?.encoder || "gpu"
    readonly property bool fallbackCpuEncoding: pluginApi?.pluginSettings?.fallbackCpuEncoding ?? false
    readonly property string keyframeInterval: pluginApi?.pluginSettings?.keyframeInterval || ""
    readonly property string postSaveScript: pluginApi?.pluginSettings?.postSaveScript || ""
    readonly property bool restorePortalSession: pluginApi?.pluginSettings?.restorePortalSession ?? false

    // Replay settings shortcuts
    readonly property bool replayEnabled: pluginApi?.pluginSettings?.replayEnabled ?? false
    readonly property string replayDuration: pluginApi?.pluginSettings?.replayDuration || "30"
    readonly property string customReplayDuration: pluginApi?.pluginSettings?.customReplayDuration || "30"
    readonly property string replayStorage: pluginApi?.pluginSettings?.replayStorage || "ram"
    readonly property bool restartReplayOnSave: (pluginApi?.pluginSettings?.restartReplayOnSave ?? false) || replayAlwaysOn
    readonly property bool dateFolders: pluginApi?.pluginSettings?.dateFolders ?? false
    readonly property bool replayAlwaysOn: pluginApi?.pluginSettings?.replayAlwaysOn ?? false

    // Track whether a replay stop was user-initiated vs. process death
    property bool _userStoppedReplay: false

    readonly property var codecResolutionLimits: ({
            "h264": "4096x4096"
        })

    function shellQuote(s) {
        return "'" + String(s).replace(/'/g, "'\\''") + "'";
    }

    function buildResolutionFlag() {
        if (resolution !== "original") {
            return `-s ${resolution}`;
        }
        var maxResolution = codecResolutionLimits[videoCodec];
        return maxResolution ? `-s ${maxResolution}` : "";
    }

    // Build repeated `-a <source>` flags, one per configured track.
    // Each track string can itself contain | to merge sources into one track.
    function buildAudioFlags() {
        if (!audioTracks || audioTracks.length === 0) return "";
        var parts = [`-ac ${audioCodec}`];
        if (audioBitrate && String(audioBitrate).length > 0) {
            parts.push(`-ab ${audioBitrate}`);
        }
        audioTracks.forEach(track => {
            var t = String(track).trim();
            if (t.length === 0) return;
            parts.push(`-a ${shellQuote(t)}`);
        });
        return parts.join(" ");
    }

    function buildExtraFlags() {
        var parts = [];
        if (container && container.length > 0) parts.push(`-c ${container}`);
        if (bitrateMode && bitrateMode !== "auto") parts.push(`-bm ${bitrateMode}`);
        if (frameRateMode && frameRateMode !== "vfr") parts.push(`-fm ${frameRateMode}`);
        if (encoder && encoder !== "gpu") parts.push(`-encoder ${encoder}`);
        if (fallbackCpuEncoding) parts.push("-fallback-cpu-encoding yes");
        if (keyframeInterval && String(keyframeInterval).length > 0) parts.push(`-keyint ${keyframeInterval}`);
        if (postSaveScript && postSaveScript.length > 0) parts.push(`-sc ${shellQuote(postSaveScript)}`);
        return parts.join(" ");
    }

    function buildTooltip() {
        if (!isAvailable) {
            return pluginApi.tr("messages.not-installed");
        }
        if (isPending) {
            pluginApi.tr("messages.started");
        }
        if (isRecording) {
            return pluginApi.tr("messages.stop-recording");
        }
        if (isReplaying) {
            return pluginApi.tr("messages.replay-active");
        }
        return pluginApi.tr("messages.start-recording");
    }

    function toggleRecording() {
        (isRecording || isPending) ? stopRecording() : startRecording();
    }

    function openFile(path) {
        if (!path) return;
        Quickshell.execDetached(["xdg-open", path]);
    }

    function copyFileToClipboard(filePath) {
        if (!filePath) return;
        const fileUri = "file://" + filePath.replace(/ /g, "%20").replace(/'/g, "%27").replace(/"/g, "%22");
        const escapedUri = fileUri.replace(/'/g, "'\\''");
        const command = "printf '%s' '" + escapedUri + "' | wl-copy --type text/uri-list";
        copyToClipboardProcess.exec({"command": ["sh", "-c", command]});
    }

    function startRecording() {
        if (!isAvailable) return;
        if (isRecording || isPending) return;
        isPending = true;
        hasActiveRecording = false;

        if ((PanelService.openedPanel !== null) && !PanelService.openedPanel.isClosing) {
            PanelService.openedPanel.close();
        }

        portalCheckProcess.exec({
            "command": ["sh", "-c", "pidof xdg-desktop-portal >/dev/null 2>&1 && (pidof xdg-desktop-portal-wlr >/dev/null 2>&1 || pidof xdg-desktop-portal-hyprland >/dev/null 2>&1 || pidof xdg-desktop-portal-gnome >/dev/null 2>&1 || pidof xdg-desktop-portal-kde >/dev/null 2>&1)"]
        });
    }

    function expandFilenamePattern(pattern) {
        var now = new Date();
        var tokens = ['unix', 'MMMM', 'dddd', 'yyyy', 'MMM', 'ddd', 'zzz', 'HH', 'hh', 'mm', 'ss', 'yy', 'MM', 'dd', 'AP', 'ap', 'M', 'd', 'H', 'h', 'm', 's', 'z', 'A', 'a', 't'];
        var escaped = "";
        var i = 0;
        var literalBuffer = "";

        while (i < pattern.length) {
            var matched = false;
            for (var j = 0; j < tokens.length; j++) {
                var token = tokens[j];
                if (pattern.substr(i, token.length) === token) {
                    if (token.length === 1) {
                        var prevChar = i > 0 ? pattern[i - 1] : "";
                        var nextChar = i + 1 < pattern.length ? pattern[i + 1] : "";
                        if ((prevChar.match(/[a-zA-Z]/) || nextChar.match(/[a-zA-Z]/))) {
                            continue;
                        }
                    }
                    if (literalBuffer) {
                        escaped += "'" + literalBuffer + "'";
                        literalBuffer = "";
                    }
                    if (token === 'unix') {
                        escaped += Math.floor(now.getTime() / 1000);
                    } else {
                        escaped += token;
                    }
                    i += token.length;
                    matched = true;
                    break;
                }
            }
            if (!matched) {
                literalBuffer += pattern[i];
                i++;
            }
        }
        if (literalBuffer) {
            escaped += "'" + literalBuffer + "'";
        }
        var expanded = I18n.locale.toString(now, escaped);
        var ext = container || "mp4";
        return expanded + "." + ext;
    }

    function launchRecorder() {
        if (videoSource === "focused-monitor" && CompositorService.isHyprland) {
            var script = 'set -euo pipefail\n' + 'pos=$(hyprctl cursorpos)\n' + 'cx=${pos%,*}; cy=${pos#*,}\n' + 'mon=$(hyprctl monitors -j | jq -r --argjson cx "$cx" --argjson cy "$cy" ' + "'.[] | select(($cx>=.x) and ($cx<(.x+.width)) and ($cy>=.y) and ($cy<(.y+.height))) | .name' " + '| head -n1)\n' + '[ -n "${mon:-}" ] || { echo "MONITOR_NOT_FOUND"; exit 1; }\n' + 'use_prime=0\n' + 'for v in /sys/class/drm/card*/device/vendor; do\n' + '  [ -f "$v" ] || continue\n' + '  if grep -qi "0x10de" "$v"; then\n' + '    card="$(basename "$(dirname "$(dirname "$v")")")"\n' + '    [ -e "/sys/class/drm/${card}-${mon}" ] && use_prime=1 && break\n' + '  fi\n' + 'done\n' + 'echo "${mon}:${use_prime}"';
            monitorDetectProcess.exec({"command": ["sh", "-c", script]});
            return;
        }
        launchRecorderWithSource(videoSource, false);
    }

    function launchRecorderWithSource(source, primeRun) {
        var pattern = filenamePattern || "recording_yyyyMMdd_HHmmss";
        var filename = expandFilenamePattern(pattern);
        var videoDir = Settings.preprocessPath(directory);
        if (!videoDir) {
            videoDir = Quickshell.env("HOME") + "/Videos";
        }
        if (videoDir && !videoDir.endsWith("/")) {
            videoDir += "/";
        }
        outputPath = videoDir + filename;

        var audioFlags = buildAudioFlags();
        var actualFrameRate = (frameRate === "custom") ? customFrameRate : frameRate;
        var resolutionFlag = buildResolutionFlag();
        var restoreFlag = restorePortalSession ? "-restore-portal-session yes" : "";
        var extraFlags = buildExtraFlags();
        var flags = `-w ${source} -f ${actualFrameRate} -k ${videoCodec} ${audioFlags} -q ${quality} -cursor ${showCursor ? "yes" : "no"} -cr ${colorRange} ${resolutionFlag} ${extraFlags} ${restoreFlag} -o "${outputPath}"`;
        var primePrefix = primeRun ? "prime-run " : "";
        var command = `
    _gpuscreenrecorder_flatpak_installed() {
    flatpak list --app | grep -q "com.dec05eba.gpu_screen_recorder"
    }
    if command -v gpu-screen-recorder >/dev/null 2>&1; then
    ${primePrefix}gpu-screen-recorder ${flags}
    elif command -v flatpak >/dev/null 2>&1 && _gpuscreenrecorder_flatpak_installed; then
    ${primePrefix}flatpak run --command=gpu-screen-recorder --file-forwarding com.dec05eba.gpu_screen_recorder ${flags}
    else
    echo "GPU_SCREEN_RECORDER_NOT_INSTALLED"
    fi`;

        recorderProcess.exec({"command": ["sh", "-c", command]});
        pendingTimer.running = true;
    }

    function stopRecording() {
        if (!isRecording && !isPending) return;
        ToastService.showNotice(pluginApi.tr("messages.stopping"), outputPath, "video");
        Quickshell.execDetached(["sh", "-c", "pkill -SIGINT -f '^(/nix/store/.*-gpu-screen-recorder|gpu-screen-recorder)' || pkill -SIGINT -f '^com.dec05eba.gpu_screen_recorder'"]);
        isRecording = false;
        isPending = false;
        pendingTimer.running = false;
        monitorTimer.running = false;
        hasActiveRecording = false;
        killTimer.running = true;
    }

    function truncateForToast(text, maxLength = 128) {
        if (text.length <= maxLength) return text;
        return text.substring(0, maxLength) + "…";
    }

    function isCancelledByUser(stdoutText, stderrText) {
        const stdout = String(stdoutText || "").toLowerCase();
        const stderr = String(stderrText || "").toLowerCase();
        const combined = stdout + " " + stderr;
        return combined.includes("canceled by") || combined.includes("cancelled by") || combined.includes("canceled by user") || combined.includes("cancelled by user") || combined.includes("canceled by the user") || combined.includes("cancelled by the user");
    }

    Process {
        id: recorderProcess
        stdout: StdioCollector {}
        stderr: StdioCollector {}
        onExited: function (exitCode, exitStatus) {
            const stdout = String(recorderProcess.stdout.text || "").trim();
            const stderr = String(recorderProcess.stderr.text || "").trim();
            const wasCancelled = isCancelledByUser(stdout, stderr);

            if (isPending) {
                isPending = false;
                pendingTimer.running = false;

                if (stdout === "GPU_SCREEN_RECORDER_NOT_INSTALLED") {
                    ToastService.showError(pluginApi.tr("messages.not-installed"), pluginApi.tr("messages.not-installed-desc"));
                    return;
                }

                if (exitCode !== 0) {
                    const filteredError = filterStderr(stderr);
                    if (filteredError.length > 0 && !wasCancelled) {
                        ToastService.showError(pluginApi.tr("messages.failed-start"), truncateForToast(filteredError));
                        Logger.e("GSR-Noctalia", filteredError);
                    }
                }
            } else if (isRecording || hasActiveRecording) {
                isRecording = false;
                monitorTimer.running = false;
                if (exitCode === 0) {
                    ToastService.showNotice(pluginApi.tr("messages.saved"), outputPath, "video", 3000, pluginApi.tr("messages.open-file"), () => openFile(outputPath));
                    if (copyToClipboard) {
                        copyFileToClipboard(outputPath);
                    }
                } else {
                    const filteredError = filterStderr(stderr);
                    if (!wasCancelled) {
                        if (filteredError.length > 0) {
                            ToastService.showError(pluginApi.tr("messages.failed-start"), truncateForToast(filteredError));
                            Logger.e("GSR-Noctalia", filteredError);
                        } else if (exitCode !== 0) {
                            ToastService.showError(pluginApi.tr("messages.failed-start"), pluginApi.tr("messages.failed-general"));
                        }
                    }
                }
                hasActiveRecording = false;
            } else if (!isPending && exitCode === 0 && outputPath) {
                ToastService.showNotice(pluginApi.tr("messages.saved"), outputPath, "video", 3000, pluginApi.tr("messages.open-file"), () => openFile(outputPath));
                if (copyToClipboard) {
                    copyFileToClipboard(outputPath);
                }
            }
        }
    }

    Process {
        id: portalCheckProcess
        onExited: function (exitCode, exitStatus) {
            if (exitCode === 0) {
                launchRecorder();
            } else {
                isPending = false;
                hasActiveRecording = false;
                ToastService.showError(pluginApi.tr("messages.no-portals"), pluginApi.tr("messages.no-portals-desc"));
            }
        }
    }

    Process {
        id: monitorDetectProcess
        stdout: StdioCollector {}
        stderr: StdioCollector {}
        onExited: function (exitCode, exitStatus) {
            const output = String(monitorDetectProcess.stdout.text || "").trim();
            if (exitCode !== 0 || output === "MONITOR_NOT_FOUND" || !output) {
                isPending = false;
                hasActiveRecording = false;
                ToastService.showError(pluginApi.tr("messages.failed-start"), pluginApi.tr("messages.monitor-not-found"));
                return;
            }
            const parts = output.split(":");
            const monitorName = parts[0];
            const primeRun = parts.length > 1 && parts[1] === "1";
            detectedMonitor = monitorName;
            usePrimeRun = primeRun;
            Logger.i("GSR-Noctalia", "Detected monitor: " + monitorName + (primeRun ? " (prime-run)" : ""));
            launchRecorderWithSource(monitorName, primeRun);
        }
    }

    Process {
        id: copyToClipboardProcess
        onExited: function (exitCode, exitStatus) {
            if (exitCode !== 0) {
                Logger.e("GSR-Noctalia", "Failed to copy file to clipboard, exit code:", exitCode);
            }
        }
    }

    Timer {
        id: pendingTimer
        interval: 2000
        running: false
        repeat: false
        onTriggered: {
            if (isPending && recorderProcess.running) {
                isPending = false;
                isRecording = true;
                hasActiveRecording = true;
                monitorTimer.running = true;
            } else if (isPending) {
                isPending = false;
            }
        }
    }

    Timer {
        id: monitorTimer
        interval: 2000
        running: false
        repeat: true
        onTriggered: {
            if (!recorderProcess.running && isRecording) {
                isRecording = false;
                running = false;
            }
        }
    }

    Timer {
        id: killTimer
        interval: 3000
        running: false
        repeat: false
        onTriggered: {
            Quickshell.execDetached(["sh", "-c", "pkill -9 -f '^(/nix/store/.*-gpu-screen-recorder|gpu-screen-recorder)' 2>/dev/null || pkill -9 -f '^com.dec05eba.gpu_screen_recorder' 2>/dev/null || true"]);
        }
    }

    // ─── Replay Buffer ───────────────────────────────────────────────────

    function toggleReplay() {
        (isReplaying || isReplayPending) ? stopReplay() : startReplay();
    }

    function startReplay() {
        if (!isAvailable) return;
        if (isReplaying || isReplayPending) return;
        if (!replayEnabled) return;

        isReplayPending = true;

        replayPortalCheckProcess.exec({
            "command": ["sh", "-c", "pidof xdg-desktop-portal >/dev/null 2>&1 && (pidof xdg-desktop-portal-wlr >/dev/null 2>&1 || pidof xdg-desktop-portal-hyprland >/dev/null 2>&1 || pidof xdg-desktop-portal-gnome >/dev/null 2>&1 || pidof xdg-desktop-portal-kde >/dev/null 2>&1)"]
        });
    }

    function launchReplay() {
        if (videoSource === "focused-monitor" && CompositorService.isHyprland) {
            var script = 'set -euo pipefail\n' + 'pos=$(hyprctl cursorpos)\n' + 'cx=${pos%,*}; cy=${pos#*,}\n' + 'mon=$(hyprctl monitors -j | jq -r --argjson cx "$cx" --argjson cy "$cy" ' + "'.[] | select(($cx>=.x) and ($cx<(.x+.width)) and ($cy>=.y) and ($cy<(.y+.height))) | .name' " + '| head -n1)\n' + '[ -n "${mon:-}" ] || { echo "MONITOR_NOT_FOUND"; exit 1; }\n' + 'use_prime=0\n' + 'for v in /sys/class/drm/card*/device/vendor; do\n' + '  [ -f "$v" ] || continue\n' + '  if grep -qi "0x10de" "$v"; then\n' + '    card="$(basename "$(dirname "$(dirname "$v")")")"\n' + '    [ -e "/sys/class/drm/${card}-${mon}" ] && use_prime=1 && break\n' + '  fi\n' + 'done\n' + 'echo "${mon}:${use_prime}"';
            replayMonitorDetectProcess.exec({"command": ["sh", "-c", script]});
            return;
        }
        launchReplayWithSource(videoSource, false);
    }

    function launchReplayWithSource(source, primeRun) {
        var videoDir = Settings.preprocessPath(directory);
        if (!videoDir) {
            videoDir = Quickshell.env("HOME") + "/Videos";
        }
        if (videoDir && !videoDir.endsWith("/")) {
            videoDir += "/";
        }

        var actualDuration = (replayDuration === "custom") ? customReplayDuration : replayDuration;
        var actualFrameRate = (frameRate === "custom") ? customFrameRate : frameRate;
        var resolutionFlag = buildResolutionFlag();
        var audioFlags = buildAudioFlags();
        var restoreFlag = restorePortalSession ? "-restore-portal-session yes" : "";
        var extraFlags = buildExtraFlags();
        var restartReplayFlag = restartReplayOnSave ? "-restart-replay-on-save yes" : "";
        var dateFoldersFlag = dateFolders ? "-df yes" : "";

        var flags = `-w ${source} -f ${actualFrameRate} -k ${videoCodec} ${audioFlags} -q ${quality} -cursor ${showCursor ? "yes" : "no"} -cr ${colorRange} ${resolutionFlag} ${extraFlags} -r ${actualDuration} -replay-storage ${replayStorage} ${restartReplayFlag} ${dateFoldersFlag} ${restoreFlag} -o "${videoDir}"`;
        var primePrefix = primeRun ? "prime-run " : "";
        var command = `
    _gpuscreenrecorder_flatpak_installed() {
    flatpak list --app | grep -q "com.dec05eba.gpu_screen_recorder"
    }
    if command -v gpu-screen-recorder >/dev/null 2>&1; then
    ${primePrefix}gpu-screen-recorder ${flags}
    elif command -v flatpak >/dev/null 2>&1 && _gpuscreenrecorder_flatpak_installed; then
    ${primePrefix}flatpak run --command=gpu-screen-recorder --file-forwarding com.dec05eba.gpu_screen_recorder ${flags}
    else
    echo "GPU_SCREEN_RECORDER_NOT_INSTALLED"
    fi`;

        replayProcess.exec({"command": ["sh", "-c", command]});
        replayPendingTimer.running = true;
    }

    function stopReplay() {
        if (!isReplaying && !isReplayPending) return;
        _userStoppedReplay = true;
        Quickshell.execDetached(["sh", "-c", "pkill -SIGINT -f '^(/nix/store/.*-gpu-screen-recorder|gpu-screen-recorder).*-r ' || pkill -SIGINT -f '^com.dec05eba.gpu_screen_recorder.*-r '"]);
        isReplaying = false;
        isReplayPending = false;
        replayPendingTimer.running = false;
        replayMonitorTimer.running = false;
        ToastService.showNotice(pluginApi.tr("messages.replay-stopped"), "", "info");
        replayKillTimer.running = true;
    }

    // Toggle 24/7 replay mode from UI
    function setAlwaysOnReplay(enabled) {
        if (!pluginApi || !pluginApi.pluginSettings) return;
        pluginApi.pluginSettings.replayAlwaysOn = enabled;
        if (enabled) {
            pluginApi.pluginSettings.restartReplayOnSave = true;
            if (!pluginApi.pluginSettings.replayEnabled) {
                pluginApi.pluginSettings.replayEnabled = true;
            }
        }
        if (pluginApi.saveSettings) pluginApi.saveSettings();
        if (enabled && isAvailable && !isReplaying && !isReplayPending) {
            _userStoppedReplay = false;
            startReplay();
        } else if (!enabled) {
            _userStoppedReplay = true;
        }
    }

    // React when user flips the 24/7 toggle in Settings
    onReplayAlwaysOnChanged: {
        if (replayAlwaysOn && replayEnabled && isAvailable && !isReplaying && !isReplayPending) {
            _userStoppedReplay = false;
            alwaysOnStartTimer.start();
        }
    }

    onReplayEnabledChanged: {
        if (replayAlwaysOn && replayEnabled && isAvailable && !isReplaying && !isReplayPending) {
            _userStoppedReplay = false;
            alwaysOnStartTimer.start();
        }
    }

    // Delay the first auto-start a moment so the shell/portals are fully up
    Timer {
        id: alwaysOnStartTimer
        interval: 3000
        repeat: false
        onTriggered: {
            if (replayAlwaysOn && replayEnabled && isAvailable && !isReplaying && !isReplayPending) {
                _userStoppedReplay = false;
                startReplay();
            }
        }
    }

    // If the replay process dies while 24/7 is on, restart it after a short delay
    Timer {
        id: replayRestartTimer
        interval: 2500
        repeat: false
        onTriggered: {
            if (replayAlwaysOn && replayEnabled && isAvailable && !isReplaying && !isReplayPending && !_userStoppedReplay) {
                startReplay();
            }
        }
    }

    function saveReplay() {
        if (!isReplaying) return;
        Quickshell.execDetached(["sh", "-c", "pkill -SIGUSR1 -f '^(/nix/store/.*-gpu-screen-recorder|gpu-screen-recorder).*-r ' || pkill -SIGUSR1 -f '^com.dec05eba.gpu_screen_recorder.*-r '"]);
    }

    Process {
        id: replayProcess
        stdout: SplitParser {
            onRead: data => {
                var savedPath = String(data).trim();
                if (savedPath && savedPath.length > 0 && !savedPath.startsWith("GPU_SCREEN_RECORDER")) {
                    ToastService.showNotice(
                        pluginApi.tr("messages.replay-saved"),
                        savedPath, "video", 3000,
                        pluginApi.tr("messages.open-file"),
                        () => openFile(savedPath)
                    );
                    if (copyToClipboard) {
                        copyFileToClipboard(savedPath);
                    }
                }
            }
        }
        stderr: StdioCollector {}
        onExited: function(exitCode, exitStatus) {
            const stderr = String(replayProcess.stderr.text || "").trim();
            const wasCancelled = isCancelledByUser("", stderr);
            const filteredError = filterStderr(stderr);

            if (isReplayPending) {
                isReplayPending = false;
                replayPendingTimer.running = false;
                if (exitCode !== 0 && filteredError.length > 0 && !wasCancelled) {
                    ToastService.showError(pluginApi.tr("messages.replay-failed"), truncateForToast(filteredError));
                    Logger.e("GSR-Noctalia", "Replay: " + filteredError);
                }
            } else if (isReplaying) {
                isReplaying = false;
                replayMonitorTimer.running = false;
                if (exitCode !== 0 && !wasCancelled) {
                    if (filteredError.length > 0) {
                        ToastService.showError(pluginApi.tr("messages.replay-failed"), truncateForToast(filteredError));
                        Logger.e("GSR-Noctalia", "Replay: " + filteredError);
                    }
                }
            }

            // 24/7 mode: auto-restart unless the user explicitly stopped us
            if (replayAlwaysOn && replayEnabled && !_userStoppedReplay) {
                replayRestartTimer.start();
            }
            _userStoppedReplay = false;
        }
    }

    function filterStderr(text) {
        if (!text) return "";
        const lines = text.split("\n");
        const errorLines = lines.filter(line => {
            const lower = line.toLowerCase();
            if (lower.includes("gsr info:") || lower.includes("gsr notice:") || lower.includes("(error: none)")) return false;
            return lower.includes("gsr error:") || lower.includes("gsr fatal:") || lower.includes("failed to") || lower.includes("error:");
        });
        if (errorLines.length === 0) return "";
        return errorLines.join("\n").trim();
    }

    Process {
        id: replayPortalCheckProcess
        onExited: function(exitCode, exitStatus) {
            if (exitCode === 0) {
                launchReplay();
            } else {
                isReplayPending = false;
                ToastService.showError(pluginApi.tr("messages.no-portals"), pluginApi.tr("messages.no-portals-desc"));
            }
        }
    }

    Process {
        id: replayMonitorDetectProcess
        stdout: StdioCollector {}
        stderr: StdioCollector {}
        onExited: function(exitCode, exitStatus) {
            const output = String(replayMonitorDetectProcess.stdout.text || "").trim();
            if (exitCode !== 0 || output === "MONITOR_NOT_FOUND" || !output) {
                isReplayPending = false;
                ToastService.showError(pluginApi.tr("messages.replay-failed"), pluginApi.tr("messages.monitor-not-found"));
                return;
            }
            const parts = output.split(":");
            const monitorName = parts[0];
            const primeRun = parts.length > 1 && parts[1] === "1";
            Logger.i("GSR-Noctalia", "Replay: Detected monitor: " + monitorName + (primeRun ? " (prime-run)" : ""));
            launchReplayWithSource(monitorName, primeRun);
        }
    }

    Timer {
        id: replayPendingTimer
        interval: 2000
        running: false
        repeat: false
        onTriggered: {
            if (root.isReplayPending && replayProcess.running) {
                root.isReplayPending = false;
                root.isReplaying = true;
                replayMonitorTimer.running = true;
                ToastService.showNotice(pluginApi.tr("messages.replay-started"), "", "info");
            } else if (root.isReplayPending) {
                root.isReplayPending = false;
            }
        }
    }

    Timer {
        id: replayMonitorTimer
        interval: 2000
        running: false
        repeat: true
        onTriggered: {
            if (!replayProcess.running && root.isReplaying) {
                root.isReplaying = false;
                running = false;
            }
        }
    }

    Timer {
        id: replayKillTimer
        interval: 3000
        running: false
        repeat: false
        onTriggered: {
            Quickshell.execDetached(["sh", "-c", "pkill -9 -f '^(/nix/store/.*-gpu-screen-recorder|gpu-screen-recorder).*-r ' 2>/dev/null || pkill -9 -f '^com.dec05eba.gpu_screen_recorder.*-r ' 2>/dev/null || true"]);
        }
    }
}
