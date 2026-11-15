pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "../core/wifi.mjs" as WifiCore

// Mode `wifi` (specs/08-controles-rapidos.md "Modo `wifi`"; design v5):
// compact header (radio row only) · session row · divider · network header ·
// stats, QR or speed · DNS · known and other networks, with the password panel
// below the chosen network. The password-panel, view and custom-DNS state lives
// in Bar.qml: it is shared by every monitor and changes the island's height.
ColumnLayout {
  id: view

  required property var bar
  readonly property var wifi: bar.system.wifi
  readonly property var groups: WifiCore.splitNetworks(wifi.list)

  spacing: 0


  // Same breathing room as `bt`: 14px above, 10px below the radio row.
  QuickHeader {
    Layout.fillWidth: true
    Layout.leftMargin: 14
    Layout.rightMargin: 14
    Layout.topMargin: 14
    Layout.bottomMargin: 10
    bar: view.bar
    // Radio row only: this view owns the Wi-Fi switch and the network list.
    compact: true
  }

  PowerRow {
    Layout.fillWidth: true
    bar: view.bar
  }

  FadeDivider {
    Layout.fillWidth: true
    Layout.bottomMargin: 8
  }

  WifiHeader {
    Layout.fillWidth: true
    Layout.leftMargin: 18
    Layout.rightMargin: 18
    Layout.bottomMargin: 8
    bar: view.bar
  }

  RadioOffArea {
    Layout.fillWidth: true
    Layout.preferredHeight: 150
    visible: !view.wifi.radioOn
    glyph: "wifi-slash"
    text: I18n.tr("Wi‑Fi off")
  }

  ColumnLayout {
    Layout.fillWidth: true
    Layout.fillHeight: true
    Layout.leftMargin: 12
    Layout.rightMargin: 12
    visible: view.wifi.radioOn
    spacing: 0

    WifiInfoArea {
      Layout.fillWidth: true
      Layout.leftMargin: 6
      Layout.rightMargin: 6
      Layout.bottomMargin: 8
      bar: view.bar
    }

    FadeDivider {
      Layout.fillWidth: true
      Layout.bottomMargin: 10
    }

    WifiDns {
      Layout.fillWidth: true
      Layout.leftMargin: 6
      Layout.rightMargin: 6
      Layout.bottomMargin: 10
      bar: view.bar
    }

    FadeDivider {
      Layout.fillWidth: true
      Layout.bottomMargin: 10
    }

    Flickable {
      Layout.fillWidth: true
      Layout.fillHeight: true
      clip: true
      boundsBehavior: Flickable.StopAtBounds
      contentHeight: lists.implicitHeight

      Column {
        id: lists

        width: parent.width

        GroupLabel {
          visible: view.groups.known.length > 0
          text: I18n.tr("Known networks")
        }

        Repeater {
          model: view.groups.known

          WifiNetworkEntry {
            width: lists.width
            bar: view.bar
            known: true
            onNetworkClicked: network => view.clickNetwork(network)
            onPasswordSubmitted: (ssid, password) => view.submit(ssid, password)
          }
        }

        GroupLabel {
          visible: view.groups.other.length > 0
          text: I18n.tr("Other networks")
        }

        Repeater {
          model: view.groups.other

          WifiNetworkEntry {
            width: lists.width
            bar: view.bar
            onNetworkClicked: network => view.clickNetwork(network)
            onPasswordSubmitted: (ssid, password) => view.submit(ssid, password)
          }
        }
      }
    }
  }

  // Rótulo de 20px, padding 0 6px, 11px maiúsculo `letter-spacing .08em`.
  component GroupLabel: Item {
    id: groupLabel

    property string text: ""

    implicitWidth: lists.width
    implicitHeight: 20

    IslandText {
      anchors.verticalCenter: parent.verticalCenter
      x: 6
      text: groupLabel.text
      px: 11
      font.weight: Tokens.weightBody
      font.capitalization: Font.AllUppercase
      font.letterSpacing: 0.88
      color: Tokens.neutral500
    }
  }

  function clickNetwork(network) {
    const action = WifiCore.clickAction(network);
    if (action === "activate") wifi.activate(network.ssid);
    else if (action === "password") bar.togglePassword(network.ssid);
    else if (action === "settings") openEnterprise(network.ssid);
  }

  // Rede 802.1X sem perfil: o Omarchy não tem app de rede, então o `nmtui`
  // num terminal flutuante pede as credenciais.
  function openEnterprise(ssid) {
    bar.closeAll();
    bar.system.session.openInTerminal("nmtui-connect", ssid);
  }

  function submit(ssid, password) {
    if (WifiCore.validatePassword(password) === "too-short") {
      bar.wifiPasswordError = WifiCore.PASSWORD_TOO_SHORT;
      return;
    }
    bar.closePassword();
    wifi.connectWithPassword(ssid, password);
  }
}
