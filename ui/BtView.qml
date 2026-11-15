pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "../core/bluetooth.mjs" as BluetoothCore

// Mode `bt` (specs/08-controles-rapidos.md): compact header (radio row only) ·
// session row · divider · section with header + switch and the "My devices" and
// "Available" lists in a single scrollable area. Scanning only runs while this
// view exists on the target monitor.
ColumnLayout {
  id: view

  required property var bar
  readonly property var bluetooth: bar.system.bluetooth

  spacing: 0

  Component.onCompleted: bluetooth.searching = true
  Component.onDestruction: bluetooth.searching = false

  // Header keeps 14px breathing room from the panel edge and 10px from the
  // divider below, like the `quick` panel does.
  QuickHeader {
    Layout.fillWidth: true
    Layout.leftMargin: 14
    Layout.rightMargin: 14
    Layout.topMargin: 14
    Layout.bottomMargin: 10
    bar: view.bar
    // Radio row only: this view owns the Bluetooth switch and the device list.
    compact: true
  }

  PowerRow {
    Layout.fillWidth: true
    bar: view.bar
  }

  Rectangle {
    Layout.fillWidth: true
    Layout.bottomMargin: 8
    implicitHeight: 1
    color: Tokens.neutral800
  }

  RadioHeader {
    Layout.fillWidth: true
    Layout.leftMargin: 12
    Layout.rightMargin: 12
    Layout.bottomMargin: 4
    glyph: "bluetooth-bold"
    title: "Bluetooth"
    status: BluetoothCore.btHeaderStatus(view.bluetooth.radioOn, view.bluetooth.connectedCount, I18n.language)
    radioOn: view.bluetooth.radioOn
    onToggled: view.bluetooth.setRadio(!view.bluetooth.radioOn)
  }

  RadioOffArea {
    Layout.fillWidth: true
    Layout.preferredHeight: 190
    visible: !view.bluetooth.radioOn
    glyph: "bluetooth-slash"
    text: I18n.tr("Bluetooth off")
  }

  Flickable {
    id: deviceArea

    Layout.fillWidth: true
    Layout.fillHeight: true
    Layout.leftMargin: 12
    Layout.rightMargin: 12
    visible: view.bluetooth.radioOn
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    contentHeight: lists.implicitHeight

    Column {
      id: lists

      // No Flickable, `parent` é o contentItem, de largura 0.
      width: deviceArea.width

      GroupLabel {
        text: I18n.tr("My devices")
        topPadding: 4
        visible: view.bluetooth.lists.paired.length > 0
      }

      Repeater {
        model: view.bluetooth.lists.paired

        delegate: DeviceRow {
          required property var modelData

          width: lists.width
          device: modelData
          onClicked: view.bluetooth.activate(modelData)
        }
      }

      Row {
        spacing: 6
        visible: view.bluetooth.lists.nearby.length > 0 || view.bluetooth.searching

        GroupLabel {
          text: I18n.tr("Available")
          topPadding: 8
        }

        PhIcon {
          anchors.bottom: parent.bottom
          anchors.bottomMargin: 3
          glyph: "circle-notch"
          size: 11
          color: Tokens.neutral500

          RotationAnimation on rotation {
            from: 0
            to: 360
            duration: 1200
            loops: Animation.Infinite
          }
        }
      }

      Repeater {
        model: view.bluetooth.lists.nearby

        delegate: DeviceRow {
          required property var modelData

          width: lists.width
          device: modelData
          onClicked: view.bluetooth.activate(modelData)
        }
      }
    }
  }

  component GroupLabel: IslandText {
    leftPadding: 8
    bottomPadding: 2
    px: 10.5
    font.capitalization: Font.AllUppercase
    font.letterSpacing: 0.63
    color: Tokens.neutral500
  }
}
