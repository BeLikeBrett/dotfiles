import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

ColumnLayout {
  id: root
  property var pluginApi: null

  property var cfg: pluginApi?.pluginSettings || ({})
  property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})

  property string serverUrl: cfg.serverUrl ?? defaults.serverUrl ?? "http://localhost:8990"
  property string apiKey: cfg.apiKey ?? defaults.apiKey ?? "brettlot-dev-key"
  property int pollIntervalSec: cfg.pollIntervalSec ?? defaults.pollIntervalSec ?? 30

  spacing: Style.marginL

  NTextInput {
    Layout.fillWidth: true
    placeholderText: pluginApi?.tr("settings.server_url.placeholder")
    text: root.serverUrl
    onTextChanged: root.serverUrl = text
  }

  NText {
    text: pluginApi?.tr("settings.server_url.label")
    font.pointSize: Style.fontSizeS
    color: Color.mOnSurfaceVariant
  }

  NTextInput {
    Layout.fillWidth: true
    placeholderText: pluginApi?.tr("settings.api_key.placeholder")
    text: root.apiKey
    onTextChanged: root.apiKey = text
  }

  NText {
    text: pluginApi?.tr("settings.api_key.label")
    font.pointSize: Style.fontSizeS
    color: Color.mOnSurfaceVariant
  }

  NTextInput {
    Layout.fillWidth: true
    placeholderText: "30"
    text: root.pollIntervalSec.toString()
    onTextChanged: {
      var val = parseInt(text);
      if (!isNaN(val) && val > 0) {
        root.pollIntervalSec = val;
      }
    }
  }

  NText {
    text: pluginApi?.tr("settings.poll_interval.label")
    font.pointSize: Style.fontSizeS
    color: Color.mOnSurfaceVariant
  }

  function saveSettings() {
    pluginApi.pluginSettings.serverUrl = root.serverUrl;
    pluginApi.pluginSettings.apiKey = root.apiKey;
    pluginApi.pluginSettings.pollIntervalSec = root.pollIntervalSec;
    pluginApi.saveSettings();
  }
}
