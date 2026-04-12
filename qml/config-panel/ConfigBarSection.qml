import QtQuick
import ".."

Column {
  id: root
  property var panel
  width: parent.width
  spacing: 8

  ConfigSectionTitle { text: "BAR" }

  ConfigToggle {
    label: "Bar enabled"
    checked: panel.getNested(panel.configData, ["components", "bar", "enabled"], true)
    onToggled: v => { panel.setNested(panel.configData, ["components", "bar", "enabled"], v); panel.configDataChanged() }
  }

  ConfigSectionTitle { text: "WEATHER"; topPad: 12 }

  ConfigToggle {
    label: "Enabled"
    checked: {
      var w = panel.getNested(panel.configData, ["components", "bar", "weather"], undefined)
      return w !== undefined && w !== false && w?.enabled !== false
    }
    onToggled: v => { panel.setNested(panel.configData, ["components", "bar", "weather", "enabled"], v); panel.configDataChanged() }
  }
  ConfigTextField {
    label: "City"
    value: panel.getNested(panel.configData, ["components", "bar", "weather", "city"], "")
    onEdited: v => { panel.setNested(panel.configData, ["components", "bar", "weather", "city"], v); panel.configDataChanged() }
  }

  ConfigSectionTitle { text: "WIFI"; topPad: 12 }

  ConfigToggle {
    label: "Enabled"
    checked: {
      var w = panel.getNested(panel.configData, ["components", "bar", "wifi"], undefined)
      return w !== undefined && w !== false && w?.enabled !== false
    }
    onToggled: v => { panel.setNested(panel.configData, ["components", "bar", "wifi", "enabled"], v); panel.configDataChanged() }
  }
  ConfigTextField {
    label: "Interface"
    value: panel.getNested(panel.configData, ["components", "bar", "wifi", "interface"], "")
    onEdited: v => { panel.setNested(panel.configData, ["components", "bar", "wifi", "interface"], v); panel.configDataChanged() }
  }

  ConfigSectionTitle { text: "WIDGETS"; topPad: 12 }

  ConfigToggle {
    label: "Bluetooth"
    checked: panel.getNested(panel.configData, ["components", "bar", "bluetooth"], true)
    onToggled: v => { panel.setNested(panel.configData, ["components", "bar", "bluetooth"], v); panel.configDataChanged() }
  }
  ConfigToggle {
    label: "Volume"
    checked: panel.getNested(panel.configData, ["components", "bar", "volume"], true)
    onToggled: v => { panel.setNested(panel.configData, ["components", "bar", "volume"], v); panel.configDataChanged() }
  }
  ConfigToggle {
    label: "Calendar"
    checked: panel.getNested(panel.configData, ["components", "bar", "calendar"], true)
    onToggled: v => { panel.setNested(panel.configData, ["components", "bar", "calendar"], v); panel.configDataChanged() }
  }

  ConfigSectionTitle { text: "MUSIC"; topPad: 12 }

  ConfigToggle {
    label: "Enabled"
    checked: {
      var m = panel.getNested(panel.configData, ["components", "bar", "music"], undefined)
      return m !== undefined && m !== false && m?.enabled !== false
    }
    onToggled: v => { panel.setNested(panel.configData, ["components", "bar", "music", "enabled"], v); panel.configDataChanged() }
  }
  ConfigTextField {
    label: "Preferred player"
    value: panel.getNested(panel.configData, ["components", "bar", "music", "preferredPlayer"], "")
    onEdited: v => { panel.setNested(panel.configData, ["components", "bar", "music", "preferredPlayer"], v); panel.configDataChanged() }
  }
  ConfigTextField {
    label: "Visualizer"
    value: panel.getNested(panel.configData, ["components", "bar", "music", "visualizer"], "")
    onEdited: v => { panel.setNested(panel.configData, ["components", "bar", "music", "visualizer"], v); panel.configDataChanged() }
  }
  ConfigToggle {
    label: "Visualizer top"
    checked: panel.getNested(panel.configData, ["components", "bar", "music", "visualizerTop"], true)
    onToggled: v => { panel.setNested(panel.configData, ["components", "bar", "music", "visualizerTop"], v); panel.configDataChanged() }
  }
  ConfigToggle {
    label: "Visualizer bottom"
    checked: panel.getNested(panel.configData, ["components", "bar", "music", "visualizerBottom"], true)
    onToggled: v => { panel.setNested(panel.configData, ["components", "bar", "music", "visualizerBottom"], v); panel.configDataChanged() }
  }
}
