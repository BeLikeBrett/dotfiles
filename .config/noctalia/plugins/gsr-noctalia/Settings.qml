import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Widgets
import qs.Services.UI
import qs.Services.Compositor

ColumnLayout {
    id: root
    spacing: Style.marginL

    // Tell NPluginSettingsPopup to use a wider dialog so long device names fit
    property real preferredWidth: 820

    property var pluginApi: null
    readonly property var mainInstance: pluginApi?.mainInstance
    readonly property var defaults: pluginApi?.manifest?.metadata?.defaultSettings ?? ({})

    property bool editHideInactive: pluginApi?.pluginSettings?.hideInactive ?? defaults.hideInactive ?? false
    property string editIconColor: pluginApi?.pluginSettings?.iconColor ?? defaults.iconColor ?? "none"
    property string editDirectory: pluginApi?.pluginSettings?.directory || defaults.directory || ""
    property string editFilenamePattern: pluginApi?.pluginSettings?.filenamePattern || defaults.filenamePattern || "recording_yyyyMMdd_HHmmss"

    readonly property var _validFrameRates: ["30", "60", "120", "custom"]
    readonly property string _rawFrameRate: pluginApi?.pluginSettings?.frameRate || defaults.frameRate || "60"
    property string editFrameRate: _validFrameRates.includes(_rawFrameRate) ? _rawFrameRate : "custom"
    property string editCustomFrameRate: _validFrameRates.includes(_rawFrameRate)
        ? (pluginApi?.pluginSettings?.customFrameRate || defaults.customFrameRate || "60")
        : _rawFrameRate
    property string editFrameRateMode: pluginApi?.pluginSettings?.frameRateMode || defaults.frameRateMode || "vfr"

    property string editAudioCodec: pluginApi?.pluginSettings?.audioCodec || defaults.audioCodec || "opus"
    property string editAudioBitrate: pluginApi?.pluginSettings?.audioBitrate ?? defaults.audioBitrate ?? ""
    property string editVideoCodec: pluginApi?.pluginSettings?.videoCodec || defaults.videoCodec || "h264"
    property string editQuality: pluginApi?.pluginSettings?.quality || defaults.quality || "very_high"
    property string editBitrateMode: pluginApi?.pluginSettings?.bitrateMode || defaults.bitrateMode || "auto"
    property string editColorRange: pluginApi?.pluginSettings?.colorRange || defaults.colorRange || "limited"
    property bool editShowCursor: pluginApi?.pluginSettings?.showCursor ?? defaults.showCursor ?? true
    property bool editCopyToClipboard: pluginApi?.pluginSettings?.copyToClipboard ?? defaults.copyToClipboard ?? false
    property string editVideoSource: pluginApi?.pluginSettings?.videoSource || defaults.videoSource || "portal"
    property string editResolution: pluginApi?.pluginSettings?.resolution || defaults.resolution || "original"
    property string editContainer: pluginApi?.pluginSettings?.container || defaults.container || "mp4"
    property string editEncoder: pluginApi?.pluginSettings?.encoder || defaults.encoder || "gpu"
    property bool editFallbackCpu: pluginApi?.pluginSettings?.fallbackCpuEncoding ?? defaults.fallbackCpuEncoding ?? false
    property string editKeyframeInterval: pluginApi?.pluginSettings?.keyframeInterval ?? defaults.keyframeInterval ?? ""
    property string editPostSaveScript: pluginApi?.pluginSettings?.postSaveScript ?? defaults.postSaveScript ?? ""
    property bool editRestorePortalSession: pluginApi?.pluginSettings?.restorePortalSession ?? defaults.restorePortalSession ?? false

    property var editAudioTracks: (pluginApi?.pluginSettings?.audioTracks !== undefined ? pluginApi.pluginSettings.audioTracks : (defaults.audioTracks ?? ["default_output"]))

    // Replay
    property bool editReplayEnabled: pluginApi?.pluginSettings?.replayEnabled ?? defaults.replayEnabled ?? false
    property bool editReplayAlwaysOn: pluginApi?.pluginSettings?.replayAlwaysOn ?? defaults.replayAlwaysOn ?? false

    readonly property var _validReplayDurations: ["15", "30", "60", "120", "300", "custom"]
    readonly property string _rawReplayDuration: pluginApi?.pluginSettings?.replayDuration || defaults.replayDuration || "30"
    property string editReplayDuration: _validReplayDurations.includes(_rawReplayDuration) ? _rawReplayDuration : "custom"
    property string editCustomReplayDuration: _validReplayDurations.includes(_rawReplayDuration)
        ? (pluginApi?.pluginSettings?.customReplayDuration || defaults.customReplayDuration || "30")
        : _rawReplayDuration
    property string editReplayStorage: pluginApi?.pluginSettings?.replayStorage || defaults.replayStorage || "ram"
    property bool editRestartReplayOnSave: pluginApi?.pluginSettings?.restartReplayOnSave ?? defaults.restartReplayOnSave ?? false
    property bool editDateFolders: pluginApi?.pluginSettings?.dateFolders ?? defaults.dateFolders ?? false

    function saveSettings() {
        if (!pluginApi || !pluginApi.pluginSettings) {
            Logger.e("GSR-Noctalia", "Cannot save: pluginApi or pluginSettings is null");
            return;
        }

        pluginApi.pluginSettings.hideInactive = root.editHideInactive
        pluginApi.pluginSettings.iconColor = root.editIconColor
        pluginApi.pluginSettings.directory = root.editDirectory
        pluginApi.pluginSettings.filenamePattern = root.editFilenamePattern
        pluginApi.pluginSettings.frameRate = root.editFrameRate
        pluginApi.pluginSettings.customFrameRate = root.editCustomFrameRate
        pluginApi.pluginSettings.frameRateMode = root.editFrameRateMode
        pluginApi.pluginSettings.audioCodec = root.editAudioCodec
        pluginApi.pluginSettings.audioBitrate = root.editAudioBitrate
        pluginApi.pluginSettings.videoCodec = root.editVideoCodec
        pluginApi.pluginSettings.quality = root.editQuality
        pluginApi.pluginSettings.bitrateMode = root.editBitrateMode
        pluginApi.pluginSettings.colorRange = root.editColorRange
        pluginApi.pluginSettings.showCursor = root.editShowCursor
        pluginApi.pluginSettings.copyToClipboard = root.editCopyToClipboard
        pluginApi.pluginSettings.audioTracks = root.editAudioTracks
        pluginApi.pluginSettings.videoSource = root.editVideoSource
        pluginApi.pluginSettings.resolution = root.editResolution
        pluginApi.pluginSettings.container = root.editContainer
        pluginApi.pluginSettings.encoder = root.editEncoder
        pluginApi.pluginSettings.fallbackCpuEncoding = root.editFallbackCpu
        pluginApi.pluginSettings.keyframeInterval = root.editKeyframeInterval
        pluginApi.pluginSettings.postSaveScript = root.editPostSaveScript
        pluginApi.pluginSettings.restorePortalSession = root.editRestorePortalSession

        pluginApi.pluginSettings.replayEnabled = root.editReplayEnabled
        pluginApi.pluginSettings.replayAlwaysOn = root.editReplayAlwaysOn
        pluginApi.pluginSettings.replayDuration = root.editReplayDuration
        pluginApi.pluginSettings.customReplayDuration = root.editCustomReplayDuration
        pluginApi.pluginSettings.replayStorage = root.editReplayStorage
        pluginApi.pluginSettings.restartReplayOnSave = root.editRestartReplayOnSave || root.editReplayAlwaysOn
        pluginApi.pluginSettings.dateFolders = root.editDateFolders

        pluginApi.saveSettings();
        Logger.i("GSR-Noctalia", "Settings saved successfully");
    }

    // ── Audio track helpers ──────────────────────────────────────────────

    // Per-track UI state: tracks whose index is in this array render in custom mode
    property var customModeIndexes: []

    function isCustomMode(index) { return customModeIndexes.indexOf(index) !== -1 }
    function setCustomMode(index, on) {
        var arr = customModeIndexes.slice();
        var pos = arr.indexOf(index);
        if (on && pos === -1) arr.push(index);
        if (!on && pos !== -1) arr.splice(pos, 1);
        customModeIndexes = arr;
    }

    function updateTrack(index, value) {
        var arr = (root.editAudioTracks || []).slice();
        arr[index] = value;
        root.editAudioTracks = arr;
    }

    function removeTrack(index) {
        var arr = (root.editAudioTracks || []).slice();
        arr.splice(index, 1);
        root.editAudioTracks = arr;
        // shift custom-mode indexes
        var newCustom = [];
        for (var i = 0; i < customModeIndexes.length; ++i) {
            var ci = customModeIndexes[i];
            if (ci < index) newCustom.push(ci);
            else if (ci > index) newCustom.push(ci - 1);
        }
        customModeIndexes = newCustom;
    }

    function addTrack() {
        var arr = (root.editAudioTracks || []).slice();
        arr.push("default_output");
        root.editAudioTracks = arr;
    }

    // Classify whether a source id is an input (mic-like)
    function isInputId(id) {
        if (!id) return false;
        if (id === "default_input") return true;
        return /^alsa_input\./.test(id);
    }

    // Parse a track string into {output, input, auto-custom flag}
    function parseTrack(str) {
        var s = String(str || "").trim();
        if (!s) return {output: "", input: "", badParse: false};
        // complex expressions always fall through to custom mode
        if (s.indexOf("app-inverse:") !== -1) return {output: "", input: "", badParse: true};
        var parts = s.split("|").map(p => p.trim()).filter(p => p.length > 0);
        if (parts.length > 2) return {output: "", input: "", badParse: true};
        var output = "";
        var input = "";
        for (var i = 0; i < parts.length; ++i) {
            var p = parts[i];
            if (isInputId(p)) {
                if (input) return {output: "", input: "", badParse: true};
                input = p;
            } else {
                if (output) return {output: "", input: "", badParse: true};
                output = p;
            }
        }
        return {output: output, input: input, badParse: false};
    }

    function serializeOI(output, input) {
        var parts = [];
        if (output) parts.push(output);
        if (input) parts.push(input);
        return parts.join("|");
    }

    // Shorten verbose PipeWire names so they fit in the dropdown.
    function shortenDeviceName(id, rawName) {
        var n = String(rawName || id || "").trim();
        var isMonitor = /(^Monitor of |\.monitor$)/i.test(n) || /\.monitor$/.test(id);
        var isInput = /^alsa_input\./i.test(id) || /(^Capture |Microphone|Mic)/i.test(n);
        n = n.replace(/^Monitor of\s+/i, "");
        n = n.replace(/\s+Analog Stereo$/i, "");
        n = n.replace(/\s+Digital Stereo.*$/i, "");
        n = n.replace(/\s+Mono(-Fallback)?$/i, "");
        n = n.replace(/\s+\(HDMI\)$/i, "");
        if (n.length > 56) n = n.substring(0, 53) + "…";
        var prefix = isMonitor ? "Out (loopback): " : (isInput ? "In (mic): " : "Device: ");
        return prefix + n;
    }

    // Output sources (system outputs + monitors + apps)
    readonly property var outputSourceModel: {
        var devices = mainInstance?.audioDevicesCache ?? [];
        var apps = mainInstance?.audioAppsCache ?? [];
        var m = [
            {"key": "default_output", "name": pluginApi?.tr("settings.audio.source-types.default_output") || "System output (default)"}
        ];
        for (var i = 0; i < devices.length; ++i) {
            var d = devices[i];
            if (!d || !d.id) continue;
            if (d.id === "default_output" || d.id === "default_input") continue;
            if (isInputId(d.id)) continue;
            m.push({"key": d.id, "name": shortenDeviceName(d.id, d.name)});
        }
        for (var j = 0; j < apps.length; ++j) {
            var a = apps[j];
            if (!a) continue;
            m.push({"key": "app:" + a, "name": "App: " + a});
        }
        return m;
    }

    // Input sources (mics / captures)
    readonly property var inputSourceModel: {
        var devices = mainInstance?.audioDevicesCache ?? [];
        var m = [
            {"key": "default_input", "name": pluginApi?.tr("settings.audio.source-types.default_input") || "Microphone input (default)"}
        ];
        for (var i = 0; i < devices.length; ++i) {
            var d = devices[i];
            if (!d || !d.id) continue;
            if (d.id === "default_output" || d.id === "default_input") continue;
            if (!isInputId(d.id)) continue;
            m.push({"key": d.id, "name": shortenDeviceName(d.id, d.name)});
        }
        return m;
    }

    // ── UI ───────────────────────────────────────────────────────────────

    NComboBox {
        label: I18n.tr("common.select-icon-color")
        description: I18n.tr("common.select-color-description")
        model: Color.colorKeyModel
        currentKey: root.editIconColor
        onSelected: key => root.editIconColor = key
        minimumWidth: 200
    }

    NTextInputButton {
        label: pluginApi.tr("settings.general.output-folder")
        description: pluginApi.tr("settings.general.output-folder-description")
        placeholderText: Quickshell.env("HOME") + "/Videos"
        text: root.editDirectory
        buttonIcon: "folder-open"
        buttonTooltip: pluginApi.tr("settings.general.output-folder")
        onInputEditingFinished: root.editDirectory = text
        onButtonClicked: folderPicker.openFilePicker()
    }

    NTextInput {
        label: pluginApi?.tr("settings.filename-pattern.label") || "Filename pattern"
        description: pluginApi?.tr("settings.filename-pattern.description") || "Pattern for generated filenames."
        placeholderText: "recording_yyyyMMdd_HHmmss"
        text: root.editFilenamePattern
        onTextChanged: root.editFilenamePattern = text
        Layout.fillWidth: true
    }

    NDivider { Layout.fillWidth: true }

    NToggle {
        label: pluginApi.tr("settings.general.show-cursor")
        description: pluginApi.tr("settings.general.show-cursor-description")
        checked: root.editShowCursor
        onToggled: c => root.editShowCursor = c
        defaultValue: defaults.showCursor ?? true
    }

    NToggle {
        label: pluginApi.tr("settings.general.copy-to-clipboard")
        description: pluginApi.tr("settings.general.copy-to-clipboard-description")
        checked: root.editCopyToClipboard
        onToggled: c => root.editCopyToClipboard = c
        defaultValue: defaults.copyToClipboard ?? false
    }

    NToggle {
        label: pluginApi.tr("settings.general.hide-when-inactive")
        description: pluginApi.tr("settings.general.hide-when-inactive-description")
        checked: root.editHideInactive
        onToggled: c => root.editHideInactive = c
        defaultValue: defaults.hideInactive ?? false
    }

    NToggle {
        label: pluginApi.tr("settings.general.restore-portal-session")
        description: pluginApi.tr("settings.general.restore-portal-session-description")
        checked: root.editRestorePortalSession
        onToggled: c => root.editRestorePortalSession = c
        defaultValue: defaults.restorePortalSession ?? false
    }

    NComboBox {
        label: pluginApi.tr("settings.general.container")
        description: pluginApi.tr("settings.general.container-desc")
        model: [
            {"key": "mp4", "name": "MP4"},
            {"key": "mkv", "name": "MKV"},
            {"key": "flv", "name": "FLV"},
            {"key": "webm", "name": "WebM"}
        ]
        currentKey: root.editContainer
        onSelected: key => root.editContainer = key
        defaultValue: defaults.container || "mp4"
    }

    NTextInput {
        label: pluginApi.tr("settings.general.post-save-script")
        description: pluginApi.tr("settings.general.post-save-script-desc")
        placeholderText: "/path/to/post-save.sh"
        text: root.editPostSaveScript
        onTextChanged: root.editPostSaveScript = text
        Layout.fillWidth: true
    }

    NDivider { Layout.fillWidth: true }

    // ── Replay section ───────────────────────────────────────────────────

    ColumnLayout {
        spacing: Style.marginL
        Layout.fillWidth: true

        NToggle {
            label: pluginApi.tr("settings.replay.enable")
            description: pluginApi.tr("settings.replay.enable-desc")
            checked: root.editReplayEnabled
            onToggled: c => root.editReplayEnabled = c
            defaultValue: defaults.replayEnabled ?? false
        }

        NToggle {
            visible: root.editReplayEnabled
            label: qsTr("Always-on replay (24/7)")
            description: qsTr("Automatically start the replay buffer when the shell loads, keep it rolling after each save, and restart it if it exits. Use saveReplay to clip.")
            checked: root.editReplayAlwaysOn
            onToggled: c => {
                root.editReplayAlwaysOn = c;
                if (c) root.editRestartReplayOnSave = true;
            }
            defaultValue: defaults.replayAlwaysOn ?? false
        }

        NComboBox {
            visible: root.editReplayEnabled
            label: pluginApi.tr("settings.replay.duration")
            description: pluginApi.tr("settings.replay.duration-desc")
            model: [
                {"key": "15", "name": "15s"},
                {"key": "30", "name": "30s"},
                {"key": "60", "name": "60s"},
                {"key": "120", "name": "2 min"},
                {"key": "300", "name": "5 min"},
                {"key": "custom", "name": pluginApi.tr("settings.video.frame-rate-custom")}
            ]
            currentKey: root.editReplayDuration
            onSelected: key => root.editReplayDuration = key
            defaultValue: defaults.replayDuration || "30"
        }

        NTextInput {
            visible: root.editReplayEnabled && root.editReplayDuration === "custom"
            label: pluginApi.tr("settings.replay.custom-duration")
            description: pluginApi.tr("settings.replay.custom-duration-desc")
            placeholderText: "30"
            text: root.editCustomReplayDuration
            onTextChanged: {
                var numeric = text.replace(/[^0-9]/g, '')
                if (numeric !== text) text = numeric
                if (numeric) root.editCustomReplayDuration = numeric
            }
            Layout.fillWidth: true
        }

        NComboBox {
            visible: root.editReplayEnabled
            label: pluginApi.tr("settings.replay.storage")
            description: pluginApi.tr("settings.replay.storage-desc")
            model: [
                {"key": "ram", "name": pluginApi.tr("settings.replay.storage-ram")},
                {"key": "disk", "name": pluginApi.tr("settings.replay.storage-disk")}
            ]
            currentKey: root.editReplayStorage
            onSelected: key => root.editReplayStorage = key
            defaultValue: defaults.replayStorage || "ram"
        }

        NToggle {
            visible: root.editReplayEnabled && !root.editReplayAlwaysOn
            label: pluginApi.tr("settings.replay.restart-on-save")
            description: pluginApi.tr("settings.replay.restart-on-save-desc")
            checked: root.editRestartReplayOnSave
            onToggled: c => root.editRestartReplayOnSave = c
            defaultValue: defaults.restartReplayOnSave ?? false
        }

        NToggle {
            visible: root.editReplayEnabled
            label: pluginApi.tr("settings.replay.date-folders")
            description: ""
            checked: root.editDateFolders
            onToggled: c => root.editDateFolders = c
            defaultValue: defaults.dateFolders ?? false
        }
    }

    NDivider { Layout.fillWidth: true }

    // ── Video section ────────────────────────────────────────────────────

    ColumnLayout {
        spacing: Style.marginL
        Layout.fillWidth: true

        NComboBox {
            label: pluginApi.tr("settings.video.source")
            description: pluginApi.tr("settings.video.source-desc")
            model: {
                let options = [
                    {"key": "portal", "name": pluginApi.tr("settings.video.sources-portal")},
                    {"key": "screen", "name": pluginApi.tr("settings.video.sources-screen")}
                ];
                if (CompositorService.isHyprland) {
                    options.push({"key": "focused-monitor", "name": pluginApi.tr("settings.video.sources-focused-monitor")});
                }
                return options;
            }
            currentKey: root.editVideoSource
            onSelected: key => root.editVideoSource = key
            defaultValue: defaults.videoSource || "portal"
        }

        NComboBox {
            label: pluginApi.tr("settings.video.frame-rate")
            description: pluginApi.tr("settings.video.frame-rate-desc")
            model: [
                {"key": "30", "name": "30 FPS"},
                {"key": "60", "name": "60 FPS"},
                {"key": "120", "name": "120 FPS"},
                {"key": "custom", "name": pluginApi.tr("settings.video.frame-rate-custom")}
            ]
            currentKey: root.editFrameRate
            onSelected: key => root.editFrameRate = key
            defaultValue: defaults.frameRate || "60"
        }

        NTextInput {
            visible: root.editFrameRate === "custom"
            label: pluginApi.tr("settings.video.custom-frame-rate")
            description: pluginApi.tr("settings.video.custom-frame-rate-desc")
            placeholderText: "60"
            text: root.editCustomFrameRate
            onTextChanged: {
                var numeric = text.replace(/[^0-9]/g, '')
                if (numeric !== text) text = numeric
                if (numeric) root.editCustomFrameRate = numeric
            }
            Layout.fillWidth: true
        }

        NComboBox {
            label: pluginApi.tr("settings.video.frame-rate-mode")
            description: pluginApi.tr("settings.video.frame-rate-mode-desc")
            model: [
                {"key": "vfr", "name": pluginApi.tr("settings.video.fr-vfr")},
                {"key": "cfr", "name": pluginApi.tr("settings.video.fr-cfr")},
                {"key": "content", "name": pluginApi.tr("settings.video.fr-content")}
            ]
            currentKey: root.editFrameRateMode
            onSelected: key => root.editFrameRateMode = key
            defaultValue: defaults.frameRateMode || "vfr"
        }

        NComboBox {
            label: pluginApi.tr("settings.video.quality")
            description: pluginApi.tr("settings.video.quality-desc")
            model: [
                {"key": "medium", "name": pluginApi.tr("settings.video.quality-medium")},
                {"key": "high", "name": pluginApi.tr("settings.video.quality-high")},
                {"key": "very_high", "name": pluginApi.tr("settings.video.quality-very-high")},
                {"key": "ultra", "name": pluginApi.tr("settings.video.quality-ultra")}
            ]
            currentKey: root.editQuality
            onSelected: key => root.editQuality = key
            defaultValue: defaults.quality || "very_high"
        }

        NComboBox {
            label: pluginApi.tr("settings.video.bitrate-mode")
            description: pluginApi.tr("settings.video.bitrate-mode-desc")
            model: [
                {"key": "auto", "name": pluginApi.tr("settings.video.bm-auto")},
                {"key": "qp", "name": pluginApi.tr("settings.video.bm-qp")},
                {"key": "vbr", "name": pluginApi.tr("settings.video.bm-vbr")},
                {"key": "cbr", "name": pluginApi.tr("settings.video.bm-cbr")}
            ]
            currentKey: root.editBitrateMode
            onSelected: key => root.editBitrateMode = key
            defaultValue: defaults.bitrateMode || "auto"
        }

        NComboBox {
            label: pluginApi.tr("settings.video.codec")
            description: pluginApi.tr("settings.video.codec-desc")
            model: {
                let options = [
                    {"key": "h264", "name": "H264"},
                    {"key": "hevc", "name": "HEVC"},
                    {"key": "hevc_10bit", "name": "HEVC 10-bit"},
                    {"key": "av1", "name": "AV1"},
                    {"key": "av1_10bit", "name": "AV1 10-bit"},
                    {"key": "vp8", "name": "VP8"},
                    {"key": "vp9", "name": "VP9"}
                ];
                if (root.editVideoSource === "screen" || root.editVideoSource === "focused-monitor") {
                    options.push({"key": "hevc_hdr", "name": "HEVC HDR"});
                    options.push({"key": "av1_hdr", "name": "AV1 HDR"});
                }
                return options;
            }
            currentKey: root.editVideoCodec
            onSelected: key => {
                root.editVideoCodec = key;
                if (key.includes("_hdr")) root.editColorRange = "full";
            }
            defaultValue: defaults.videoCodec || "h264"

            Connections {
                target: root
                function onEditVideoSourceChanged() {
                    if (root.editVideoSource !== "screen" && root.editVideoSource !== "focused-monitor" && (root.editVideoCodec === "av1_hdr" || root.editVideoCodec === "hevc_hdr")) {
                        root.editVideoCodec = "h264";
                    }
                }
            }
        }

        NComboBox {
            label: pluginApi.tr("settings.video.color-range")
            description: pluginApi.tr("settings.video.color-range-desc")
            model: [
                {"key": "limited", "name": pluginApi.tr("settings.video.color-range-limited")},
                {"key": "full", "name": pluginApi.tr("settings.video.color-range-full")}
            ]
            currentKey: root.editColorRange
            onSelected: key => root.editColorRange = key
            defaultValue: defaults.colorRange || "limited"
        }

        NComboBox {
            label: pluginApi.tr("settings.video.resolution")
            description: pluginApi.tr("settings.video.resolution-desc")
            model: [
                {"key": "original", "name": pluginApi.tr("settings.video.resolution-original")},
                {"key": "1920x1080", "name": "1920x1080 (Full HD)"},
                {"key": "1920x1200", "name": "1920x1200 (WUXGA)"},
                {"key": "2560x1440", "name": "2560x1440 (QHD)"},
                {"key": "3840x2160", "name": "3840x2160 (4K)"},
                {"key": "1280x720", "name": "1280x720 (HD)"}
            ]
            currentKey: root.editResolution
            onSelected: key => root.editResolution = key
            defaultValue: defaults.resolution || "original"
        }

        NComboBox {
            label: pluginApi.tr("settings.video.encoder")
            description: pluginApi.tr("settings.video.encoder-desc")
            model: [
                {"key": "gpu", "name": pluginApi.tr("settings.video.enc-gpu")},
                {"key": "cpu", "name": pluginApi.tr("settings.video.enc-cpu")}
            ]
            currentKey: root.editEncoder
            onSelected: key => root.editEncoder = key
            defaultValue: defaults.encoder || "gpu"
        }

        NToggle {
            label: pluginApi.tr("settings.video.fallback-cpu")
            description: pluginApi.tr("settings.video.fallback-cpu-desc")
            checked: root.editFallbackCpu
            onToggled: c => root.editFallbackCpu = c
            defaultValue: defaults.fallbackCpuEncoding ?? false
        }

        NTextInput {
            label: pluginApi.tr("settings.video.keyint")
            description: pluginApi.tr("settings.video.keyint-desc")
            placeholderText: "2.0"
            text: root.editKeyframeInterval
            onTextChanged: root.editKeyframeInterval = text
            Layout.fillWidth: true
        }
    }

    NDivider { Layout.fillWidth: true }

    // ── Audio section ────────────────────────────────────────────────────

    ColumnLayout {
        spacing: Style.marginL
        Layout.fillWidth: true

        NText {
            text: pluginApi.tr("settings.audio.tracks-title")
            font.pixelSize: Style.fontSizeL
            font.bold: true
        }

        NText {
            text: pluginApi.tr("settings.audio.tracks-desc")
            color: Color.mOnSurfaceVariant
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }

        // Track rows
        Repeater {
            model: root.editAudioTracks

            delegate: Rectangle {
                id: trackRow
                Layout.fillWidth: true
                color: Color.mSurfaceVariant
                radius: Style.radiusM
                border.color: Color.mOutline
                border.width: Style.borderS
                implicitHeight: trackContent.implicitHeight + Style.marginM * 2

                required property int index
                required property var modelData

                readonly property string trackValue: String(modelData ?? "")
                readonly property var parsed: root.parseTrack(trackValue)
                readonly property string outputValue: parsed.output
                readonly property string inputValue: parsed.input
                readonly property bool hasOutput: outputValue.length > 0
                readonly property bool hasInput: inputValue.length > 0
                readonly property bool isCustom: parsed.badParse || root.isCustomMode(index)

                function setOutput(v) { root.updateTrack(index, root.serializeOI(v, inputValue)) }
                function setInput(v)  { root.updateTrack(index, root.serializeOI(outputValue, v)) }

                ColumnLayout {
                    id: trackContent
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: Style.marginM
                    spacing: Style.marginS

                    // Header
                    RowLayout {
                        Layout.fillWidth: true
                        NText {
                            text: pluginApi.tr("settings.audio.track-label") + " " + (trackRow.index + 1)
                            font.bold: true
                            pointSize: Style.fontSizeM
                            Layout.fillWidth: true
                        }
                        NIconButton {
                            icon: "trash"
                            tooltipText: pluginApi.tr("settings.audio.remove-track")
                            colorFg: Color.mError
                            onClicked: root.removeTrack(trackRow.index)
                        }
                    }

                    // ── Simple mode: Output row ────────────────────────────
                    RowLayout {
                        visible: !trackRow.isCustom && trackRow.hasOutput
                        Layout.fillWidth: true
                        spacing: Style.marginS
                        NText {
                            text: qsTr("Output")
                            Layout.preferredWidth: 60
                        }
                        NComboBox {
                            Layout.fillWidth: true
                            minimumWidth: 380
                            popupHeight: 280
                            model: root.outputSourceModel
                            currentKey: trackRow.outputValue
                            onSelected: key => trackRow.setOutput(key)
                        }
                        NIconButton {
                            icon: "x"
                            tooltipText: qsTr("Remove output from this track")
                            onClicked: trackRow.setOutput("")
                        }
                    }

                    // ── Simple mode: Input row ─────────────────────────────
                    RowLayout {
                        visible: !trackRow.isCustom && trackRow.hasInput
                        Layout.fillWidth: true
                        spacing: Style.marginS
                        NText {
                            text: qsTr("Input")
                            Layout.preferredWidth: 60
                        }
                        NComboBox {
                            Layout.fillWidth: true
                            minimumWidth: 380
                            popupHeight: 280
                            model: root.inputSourceModel
                            currentKey: trackRow.inputValue
                            onSelected: key => trackRow.setInput(key)
                        }
                        NIconButton {
                            icon: "x"
                            tooltipText: qsTr("Remove input from this track")
                            onClicked: trackRow.setInput("")
                        }
                    }

                    // ── Simple mode: Add-slot + custom toggle ──────────────
                    RowLayout {
                        visible: !trackRow.isCustom
                        Layout.fillWidth: true
                        spacing: Style.marginS

                        NButton {
                            visible: !trackRow.hasOutput
                            text: qsTr("+ Add output")
                            onClicked: trackRow.setOutput("default_output")
                        }
                        NButton {
                            visible: !trackRow.hasInput
                            text: qsTr("+ Add input")
                            onClicked: trackRow.setInput("default_input")
                        }
                        Item { Layout.fillWidth: true }
                        NButton {
                            text: qsTr("Custom expression…")
                            onClicked: root.setCustomMode(trackRow.index, true)
                        }
                    }

                    // ── Custom mode: free-form expression ──────────────────
                    ColumnLayout {
                        visible: trackRow.isCustom
                        Layout.fillWidth: true
                        spacing: Style.marginXS

                        NText {
                            text: qsTr("Custom expression (advanced)")
                            color: Color.mOnSurfaceVariant
                        }
                        NTextInput {
                            id: customInput
                            Layout.fillWidth: true
                            placeholderText: "e.g. app:firefox   •   default_output|app:discord   •   app-inverse:firefox"
                            text: trackRow.trackValue
                            onEditingFinished: {
                                if (customInput.text !== trackRow.trackValue) {
                                    root.updateTrack(trackRow.index, customInput.text);
                                }
                            }
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            Item { Layout.fillWidth: true }
                            NButton {
                                text: qsTr("Back to simple mode")
                                onClicked: {
                                    root.setCustomMode(trackRow.index, false);
                                    // If it doesn't parse cleanly, blank it so simple mode can start fresh
                                    if (trackRow.parsed.badParse) {
                                        root.updateTrack(trackRow.index, "");
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        NText {
            visible: (root.editAudioTracks || []).length === 0
            text: pluginApi.tr("settings.audio.no-tracks")
            color: Color.mOnSurfaceVariant
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Style.marginS

            NButton {
                text: pluginApi.tr("settings.audio.add-track")
                icon: "plus"
                onClicked: root.addTrack()
            }

            NButton {
                text: pluginApi.tr("settings.audio.refresh-devices")
                icon: "refresh"
                onClicked: if (mainInstance) mainInstance.refreshAudioDevices()
            }
        }

        NComboBox {
            label: pluginApi.tr("settings.audio.codec")
            description: pluginApi.tr("settings.audio.codec-desc")
            model: [
                {"key": "opus", "name": "Opus"},
                {"key": "aac", "name": "AAC"}
            ]
            currentKey: root.editAudioCodec
            onSelected: key => root.editAudioCodec = key
            defaultValue: defaults.audioCodec || "opus"
        }

        NTextInput {
            label: pluginApi.tr("settings.audio.bitrate")
            description: pluginApi.tr("settings.audio.bitrate-desc")
            placeholderText: "128"
            text: root.editAudioBitrate
            onTextChanged: {
                var numeric = text.replace(/[^0-9]/g, '')
                if (numeric !== text) text = numeric
                root.editAudioBitrate = numeric
            }
            Layout.fillWidth: true
        }
    }

    Item { Layout.fillHeight: true }

    NFilePicker {
        id: folderPicker
        selectionMode: "folders"
        title: pluginApi.tr("settings.general.output-folder")
        initialPath: root.editDirectory || Quickshell.env("HOME") + "/Videos"
        onAccepted: paths => {
            if (paths.length > 0) {
                root.editDirectory = paths[0];
            }
        }
    }
}
