pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "../core/workspaces.mjs" as WorkspacesCore
import "../core/musicWidget.mjs" as MusicWidgetCore

// Aba Customization do editor: preferências dos widgets de workspaces e de
// música. Ficam no `settings.json` como as da aparência, e cada troca vale
// na hora (specs/16-widgets.md).
RowLayout {
  id: page

  required property var bar
  readonly property var ws: page.bar.service ? page.bar.service.settings.values : null

  function workspaceMode(id) {
    if (page.bar.service) page.bar.service.setWorkspaceMode(id);
  }

  function workspaceIconLimit(limit) {
    if (page.bar.service) page.bar.service.setWorkspaceIconLimit(limit);
  }

  function workspaceIconSize(size) {
    if (page.bar.service) page.bar.service.setWorkspaceIconSize(size);
  }

  function workspaceFlag(key, on) {
    if (page.bar.service) page.bar.service.setWorkspaceFlag(key, on);
  }

  function musicMode(id) {
    if (page.bar.service) page.bar.service.setMusicMode(id);
  }

  function musicFlag(key, on) {
    if (page.bar.service) page.bar.service.setMusicFlag(key, on);
  }

  function musicMaxWidth(width) {
    if (page.bar.service) page.bar.service.setMusicMaxWidth(width);
  }

  spacing: 14

  ColumnLayout {
    Layout.fillWidth: true
    Layout.preferredWidth: 1
    Layout.alignment: Qt.AlignTop
    spacing: 14

    // Widget de workspaces (spec 16). O modo, o teto de ícones e a numeração
    // local são os mesmos do `advanced-workspaces` (MIT).
    SettingsSection {
      Layout.fillWidth: true
      title: I18n.tr("Workspaces")

      ChoiceRow {
        Layout.fillWidth: true
        label: I18n.tr("Mode")
        hint: I18n.tr("Only used keeps the empty ones off the bar.")
        options: WorkspacesCore.MODE_IDS.map(id => ({ id: id, label: I18n.tr(WorkspacesCore.MODE_NAMES[id]) }))
        current: WorkspacesCore.modeOf(page.ws ? page.ws.wsShowEmpty : false)
        onChosen: id => page.workspaceMode(id)
      }

      SwitchRow {
        Layout.fillWidth: true
        label: I18n.tr("Icons")
        hint: I18n.tr("Every open window's real logo.")
        on: page.ws ? page.ws.wsShowIcons : true
        onToggled: on => page.workspaceFlag("wsShowIcons", on)
      }

      ChoiceRow {
        Layout.fillWidth: true
        visible: page.ws ? page.ws.wsShowIcons : true
        label: I18n.tr("Icons per pill")
        hint: I18n.tr("The rest folds into +N.")
        options: WorkspacesCore.ICON_LIMITS.map(limit => ({ id: String(limit), label: I18n.tr(WorkspacesCore.iconLimitLabel(limit)) }))
        current: String(page.ws ? page.ws.wsMaxIcons : 0)
        onChosen: id => page.workspaceIconLimit(Number(id))
      }

      SliderRow {
        Layout.fillWidth: true
        visible: page.ws ? page.ws.wsShowIcons : true
        label: I18n.tr("Icon size")
        from: 6
        to: 24
        unit: "px"
        value: page.ws ? page.ws.wsIconSize : 12
        onMoved: value => page.workspaceIconSize(value)
      }

      SwitchRow {
        Layout.fillWidth: true
        label: I18n.tr("Only this monitor's workspaces")
        hint: I18n.tr("Off draws them all on every bar.")
        on: page.ws ? page.ws.wsPerMonitor : true
        onToggled: on => page.workspaceFlag("wsPerMonitor", on)
      }

      SwitchRow {
        Layout.fillWidth: true
        label: I18n.tr("Scratchpad pill")
        hint: I18n.tr("While the scratchpad holds windows.")
        on: page.ws ? page.ws.wsScratchpad : true
        onToggled: on => page.workspaceFlag("wsScratchpad", on)
      }
    }
  }

  ColumnLayout {
    Layout.fillWidth: true
    Layout.preferredWidth: 1
    Layout.alignment: Qt.AlignTop
    spacing: 14

    SettingsSection {
      Layout.fillWidth: true
      title: I18n.tr("Music")

      SettingRow {
        Layout.fillWidth: true
        label: I18n.tr("Mode")
        hint: I18n.tr("Compact: title only; Full: title and artist; Minimal: icon only; Controls: with playback buttons.")
      }

      RowLayout {
        Layout.fillWidth: true
        spacing: 6

        Repeater {
          model: MusicWidgetCore.MUSIC_MODES.map(id => ({ id: id, label: I18n.tr(MusicWidgetCore.MUSIC_MODE_LABELS[id]) }))

          ChoiceButton {
            required property var modelData

            Layout.fillWidth: true
            label: modelData.label
            active: (page.ws ? page.ws.musicMode : "compact") === modelData.id
            onClicked: page.musicMode(modelData.id)
          }
        }
      }

      SwitchRow {
        Layout.fillWidth: true
        label: I18n.tr("Album art")
        hint: I18n.tr("Show album thumbnail when available.")
        on: page.ws ? page.ws.musicShowArt : true
        onToggled: on => page.musicFlag("musicShowArt", on)
      }

      SwitchRow {
        Layout.fillWidth: true
        label: I18n.tr("Sound waves")
        hint: I18n.tr("Animated visualizer waves while playing.")
        on: page.ws ? page.ws.musicShowWaves : true
        onToggled: on => page.musicFlag("musicShowWaves", on)
      }

      SwitchRow {
        Layout.fillWidth: true
        label: I18n.tr("Hide when inactive")
        hint: I18n.tr("Hides the widget when nothing is playing.")
        on: page.ws ? page.ws.musicHideIdle : false
        onToggled: on => page.musicFlag("musicHideIdle", on)
      }

      SliderRow {
        Layout.fillWidth: true
        visible: (page.ws ? page.ws.musicMode : "compact") !== "minimal"
        label: I18n.tr("Max title width")
        hint: I18n.tr("Limits the title length on the bar.")
        from: 80
        to: 300
        unit: "px"
        value: page.ws ? page.ws.musicMaxWidth : 140
        onMoved: value => page.musicMaxWidth(value)
      }
    }
  }
}
