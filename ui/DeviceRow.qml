pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "../core/bluetooth.mjs" as BluetoothCore

// Device row (specs/08-controles-rapidos.md "Modo `bt`"): 38px, 10px gap:
// `ph-fill` icon 17px · name 12.5px · battery (only when connected and level is
// known) · status 11px on the right · trash icon on paired devices.
//
// "Forget" takes two clicks (the trash arms `confirming`, ✓ runs it, ✕
// disarms): forgetting drops the bond in BlueZ and the next use has to pair
// again, so it cannot be a single click — and the button sits at the end of the
// row, out of the way of the click that connects/disconnects.
ListRow {
  id: row

  required property var device
  readonly property var battery: BluetoothCore.visibleBattery(device)
  readonly property bool forgetable: BluetoothCore.canForget(device)
  // Confirmation target: only this row's device, and only while it exists.
  property bool confirming: false
  readonly property var statuses: ({
      connected: { text: I18n.tr("Connected"), color: Tokens.accent300 },
      disconnected: { text: I18n.tr("Disconnected"), color: Tokens.neutral500 },
      pair: { text: I18n.tr("Pair"), color: Tokens.accent300 },
      connecting: { text: I18n.tr("Connecting…"), color: Tokens.neutral400 },
      disconnecting: { text: I18n.tr("Disconnecting…"), color: Tokens.neutral400 },
      pairing: { text: I18n.tr("Pairing…"), color: Tokens.neutral400 },
      forgetting: { text: I18n.tr("Forgetting…"), color: Tokens.neutral400 }
    })
  readonly property var kindGlyphs: ({
      headphones: "headphones-fill",
      mouse: "mouse-fill",
      keyboard: "keyboard-fill",
      speaker: "speaker-hifi-fill",
      phone: "device-mobile-fill",
      computer: "laptop-fill",
      gamepad: "game-controller-fill",
      other: "bluetooth-fill"
    })

  signal forget

  implicitHeight: 38
  active: device.connected

  // Paired, connected or gone from the list: a pending question is stale.
  onDeviceChanged: confirming = false

  Timer {
    id: confirmTimer

    interval: 4000
    onTriggered: row.confirming = false
  }

  RowLayout {
    anchors.fill: parent
    spacing: 10

    PhIcon {
      glyph: row.kindGlyphs[row.device.kind]
      size: 17
      color: row.device.connected ? Tokens.accent : Tokens.neutral300
    }

    IslandText {
      text: row.device.name
      px: 12.5
      font.weight: Tokens.weightBody
      elide: Text.ElideRight
      Layout.maximumWidth: 260
    }

    Row {
      visible: row.battery !== null
      spacing: 4

      PhIcon {
        anchors.verticalCenter: parent.verticalCenter
        glyph: "battery-medium-fill"
        size: 13
        color: Tokens.neutral400
      }

      IslandText {
        anchors.verticalCenter: parent.verticalCenter
        text: row.battery + "%"
        px: 11
        font.weight: Tokens.weightBody
        color: Tokens.neutral400
      }
    }

    IslandText {
      Layout.fillWidth: true
      horizontalAlignment: Text.AlignRight
      visible: !row.confirming
      text: row.statuses[row.device.status].text
      color: row.statuses[row.device.status].color
      px: 11
      font.weight: Tokens.weightBody
    }

    IslandText {
      Layout.fillWidth: true
      horizontalAlignment: Text.AlignRight
      visible: row.confirming
      text: I18n.tr("Forget?")
      color: Tokens.powerOffText
      px: 11
      font.weight: Tokens.weightBody
    }

    Row {
      spacing: 2
      Layout.alignment: Qt.AlignVCenter

      DeviceAction {
        // Always visible (discreet); the row's hover is what brightens it.
        // Don't tie visibility to hover: if the button's `MouseArea` stole the
        // row hover, the button would flicker under the cursor.
        visible: row.forgetable && !row.confirming
        glyph: "trash"
        tint: row.hovered ? Tokens.neutral300 : Tokens.neutral500
        onTriggered: {
          row.confirming = true;
          confirmTimer.restart();
        }
      }

      DeviceAction {
        visible: row.confirming
        glyph: "check-bold"
        tint: Tokens.accent
        onTriggered: {
          confirmTimer.stop();
          row.confirming = false;
          row.forget();
        }
      }

      DeviceAction {
        visible: row.confirming
        glyph: "x"
        tint: Tokens.neutral400
        onTriggered: {
          confirmTimer.stop();
          row.confirming = false;
        }
      }
    }
  }

  component DeviceAction: Item {
    id: action

    required property string glyph
    required property color tint
    signal triggered

    implicitWidth: 20
    implicitHeight: 20

    PhIcon {
      anchors.centerIn: parent
      glyph: action.glyph
      size: 13
      color: action.tint
    }

    MouseArea {
      anchors.fill: parent
      // No hoverEnabled on purpose: the hover highlight belongs to the whole
      // row, and a hovering MouseArea here would steal it from `ListRow`.
      cursorShape: Qt.PointingHandCursor
      onClicked: action.triggered()
    }
  }
}
