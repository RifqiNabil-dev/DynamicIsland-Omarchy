pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

// Cabeçalho de control center (design de referência do usuário): fileira de
// rádios (Wi-Fi · Bluetooth · Configurações) e fileira de modos (Foco · Luz
// noturna · Energia), com pílulas de 72px. Vive no `quick` e também no topo de
// `wifi`/`bt`, que antes mostravam a `ControlsRow` de 46px — assim o visual
// antigo não aparece em painel nenhum.
Item {
  id: header

  required property var bar
  readonly property var system: bar.system

  readonly property int gap: 10

  // 68 + 10 + 68: as duas fileiras.
  implicitHeight: 146

  // Pílula grande: círculo de ícone, título, estado e chevron. Ligada, o
  // círculo fica branco com a tinta escura.
  component PanelPill: Rectangle {
    id: pill

    required property string glyph
    property string title: ""
    property string subtitle: ""
    property bool on: false
    property bool chevron: false
    property bool interactive: true

    signal clicked

    readonly property bool hovered: pointer.containsMouse

    implicitHeight: 68
    radius: 19
    color: pill.hovered && pill.interactive ? Tokens.neutral700 : Tokens.tileOff

    Behavior on color {
      ColorAnimation {
        duration: 160
      }
    }

    RowLayout {
      anchors.fill: parent
      anchors.leftMargin: 14
      anchors.rightMargin: 14
      spacing: 12

      Rectangle {
        implicitWidth: 40
        implicitHeight: 40
        radius: 20
        color: pill.on ? Tokens.neutral100 : Qt.alpha(Tokens.text, 0.09)

        PhIcon {
          anchors.centerIn: parent
          glyph: pill.glyph
          size: 20
          color: pill.on ? Tokens.neutral900 : Tokens.neutral100
        }
      }

      ColumnLayout {
        Layout.fillWidth: true
        spacing: 1

        IslandText {
          Layout.fillWidth: true
          text: pill.title
          px: 15
          elide: Text.ElideRight
        }

        IslandText {
          Layout.fillWidth: true
          visible: pill.subtitle !== ""
          text: pill.subtitle
          px: 12
          color: Tokens.neutral400
          font.weight: Tokens.weightBody
          elide: Text.ElideRight
        }
      }

      PhIcon {
        visible: pill.chevron
        glyph: "caret-right"
        size: 14
        color: Tokens.neutral400
      }
    }

    MouseArea {
      id: pointer

      anchors.fill: parent
      enabled: pill.interactive
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: pill.clicked()
    }
  }

  // Botão redondo de 68px que fecha cada fileira.
  component RoundAction: Rectangle {
    id: action

    required property string glyph

    signal clicked

    readonly property bool hovered: pointer.containsMouse

    implicitWidth: 68
    implicitHeight: 68
    radius: 34
    color: action.hovered ? Tokens.neutral700 : Tokens.tileOff

    Behavior on color {
      ColorAnimation {
        duration: 160
      }
    }

    PhIcon {
      anchors.centerIn: parent
      glyph: action.glyph
      size: 22
      color: Tokens.neutral200
    }

    MouseArea {
      id: pointer

      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: action.clicked()
    }
  }


  ColumnLayout {
    id: headerCol
    anchors.fill: parent
    spacing: header.gap
    Component.onCompleted: console.log("QHCOL", width, height)

    // Fileira 1: rádios conectados e Configurações.
    RowLayout {
      id: row1
      Layout.fillWidth: true
      spacing: header.gap

      PanelPill {
        Layout.fillWidth: true
        visible: header.system.wifi.available
        glyph: header.system.wifi.radioOn ? "wifi-high-bold" : "wifi-slash-bold"
        title: I18n.tr("Wi-Fi")
        subtitle: {
          const active = header.system.wifi.active;
          if (!header.system.wifi.radioOn) return I18n.tr("Off");
          return active !== null && active.ssid ? String(active.ssid) : I18n.tr("Not connected");
        }
        on: header.system.wifi.radioOn
        chevron: true
        onClicked: header.bar.openFromBar(header.bar.targetScreen, header.bar.mode === "wifi" ? "quick" : "wifi")
      }

      PanelPill {
        Layout.fillWidth: true
        visible: header.system.bluetooth.available
        glyph: "bluetooth-bold"
        title: I18n.tr("Bluetooth")
        subtitle: header.system.bluetooth.radioOn ? I18n.tr("On") : I18n.tr("Off")
        on: header.system.bluetooth.radioOn
        chevron: true
        onClicked: header.bar.openFromBar(header.bar.targetScreen, header.bar.mode === "bt" ? "quick" : "bt")
      }

      RoundAction {
        glyph: "gear-six"
        // Fecha antes de abrir: com o foco exclusivo da ilha, o menu não o pegaria.
        onClicked: {
          header.bar.closeAll();
          header.system.session.openSettings();
        }
      }
    }

    // Fileira 2: modos e Energia.
    RowLayout {
      id: row2
      Layout.fillWidth: true
      spacing: header.gap

      PanelPill {
        Layout.fillWidth: true
        visible: header.bar.service !== null
        glyph: header.bar.service !== null && header.bar.service.doNotDisturb ? "bell-slash-fill" : "bell-fill"
        title: I18n.tr("Focus")
        subtitle: header.bar.service !== null && header.bar.service.doNotDisturb ? I18n.tr("On") : I18n.tr("Off")
        on: header.bar.service !== null && header.bar.service.doNotDisturb
        onClicked: if (header.bar.service) header.bar.service.setDoNotDisturb(!header.bar.service.doNotDisturb)
      }

      PanelPill {
        Layout.fillWidth: true
        visible: header.system.nightLight.available
        glyph: "moon-stars"
        title: I18n.tr("Night light")
        subtitle: header.system.nightLight.on ? I18n.tr("On") : I18n.tr("Off")
        on: header.system.nightLight.on
        onClicked: header.system.nightLight.toggle()
      }

      RoundAction {
        glyph: "power-bold"
        onClicked: header.bar.islandState.togglePower()
      }
    }
  }
}
