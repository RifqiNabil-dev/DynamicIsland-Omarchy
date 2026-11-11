pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "../core/vpn.mjs" as VpnCore

// Modo `vpn`: o painel replica o app da NordVPN — cabeçalho com ponto de
// status, país em destaque e a linha `cidade · país #id · transporte`, a grade
// 2×4 de métricas, o mapa com o marcador do servidor, os atalhos de país e as
// opções do daemon. O layout segue o app; as cores saem do `Tokens`, então o
// painel continua com o tema e o realce do Island.
Item {
  id: view

  required property var bar
  readonly property var vpn: bar.system.vpn
  readonly property var panel: VpnCore.vpnPanel(vpn.state, vpn.rates, vpn.latency, I18n.language, vpn.options, vpn.countries)
  readonly property bool offline: !vpn.installed
  // O cartão mostra o mapa (visão do app) ou a lista completa de países.
  property bool listMode: false
  // 150 países num espaço curto: a busca reduz antes de rolar.
  readonly property var filteredCountries: {
    const list = view.panel.countries || [];
    const query = countryFilter.text.trim().toLowerCase();
    if (query === "")
      return list;
    return list.filter((country) => country.label.toLowerCase().includes(query));
  }

  ColumnLayout {
    anchors.fill: parent
    anchors.leftMargin: 16
    anchors.rightMargin: 16
    anchors.topMargin: 14
    anchors.bottomMargin: 14
    spacing: 0

    // Cabeçalho: ponto de status + país + `cidade · país #id · transporte` e a
    // ação (conectar/desconectar) à direita.
    RowLayout {
      Layout.fillWidth: true
      Layout.preferredHeight: 44
      spacing: 12

      Item {
        Layout.alignment: Qt.AlignVCenter
        implicitWidth: 16
        implicitHeight: 16

        Rectangle {
          anchors.centerIn: parent
          width: 16
          height: 16
          radius: 8
          visible: view.panel.online || view.panel.connecting
          color: Qt.alpha(view.panel.online ? Tokens.accent : Tokens.neutral400, 0.22)
        }

        Rectangle {
          anchors.centerIn: parent
          width: 8
          height: 8
          radius: 4
          color: view.panel.online ? Tokens.accent : view.panel.connecting ? Tokens.neutral400 : Tokens.neutral600

          Behavior on color {
            ColorAnimation {
              duration: 180
            }
          }
        }
      }

      ColumnLayout {
        Layout.fillWidth: true
        spacing: 1

        IslandText {
          Layout.fillWidth: true
          text: view.offline ? I18n.tr("NordVPN CLI not found") : view.panel.country
          px: 19
          color: Tokens.text
          elide: Text.ElideRight
        }

        IslandText {
          Layout.fillWidth: true
          visible: text !== ""
          text: view.panel.meta
          px: 10.5
          color: Tokens.neutral400
          elide: Text.ElideRight
          font.letterSpacing: 0.4
          font.capitalization: Font.AllUppercase
        }
      }

      // Ação compacta do cabeçalho (`.btn-primary` reduzido).
      Rectangle {
        id: action

        Layout.alignment: Qt.AlignVCenter
        implicitWidth: Math.max(84, actionLabel.implicitWidth + 22)
        implicitHeight: 28
        radius: 8
        border.width: 1
        border.color: view.panel.action.enabled ? Tokens.accent : Tokens.neutral800
        color: actionArea.pressed ? Tokens.btnPrimaryActive : actionArea.containsMouse ? Tokens.btnPrimaryHover : "transparent"

        Behavior on border.color {
          ColorAnimation {
            duration: 150
          }
        }

        IslandText {
          id: actionLabel

          anchors.centerIn: parent
          text: view.panel.action.label
          px: 11.5
          color: view.panel.action.enabled ? Tokens.accent : Tokens.neutral500
        }

        MouseArea {
          id: actionArea

          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: if (view.panel.action.enabled) view.vpn.toggle()
        }
      }
    }

    // Métricas: 2×4, rótulo em caixa alta e valor tabular.
    Section {
      GridLayout {
        Layout.fillWidth: true
        columns: 4
        columnSpacing: 12
        rowSpacing: 6

        Repeater {
          model: view.panel.metrics

          ColumnLayout {
            required property var modelData

            Layout.fillWidth: true
            Layout.preferredWidth: 1
            spacing: 2

            IslandText {
              Layout.fillWidth: true
              text: modelData.label
              px: 9.5
              color: Tokens.neutral500
              elide: Text.ElideRight
              font.letterSpacing: 0.5
              font.capitalization: Font.AllUppercase
            }

            IslandText {
              Layout.fillWidth: true
              text: modelData.value
              px: 12
              color: Tokens.neutral200
              elide: Text.ElideRight
            }
          }
        }
      }
    }

    // Cartão geográfico: faixa `CONECTADO · JAPÃO` e o alternador Peta/Daftar
    // (como no app); abaixo, o mapa com o marcador ou a lista de todos os
    // países que o daemon aceita.
    Section {
      ColumnLayout {
        Layout.fillWidth: true
        spacing: 6

        RowLayout {
          Layout.fillWidth: true
          Layout.preferredHeight: 22
          spacing: 6

          Rectangle {
            implicitWidth: badge.implicitWidth + 16
            implicitHeight: 22
            radius: 11
            color: Qt.alpha(Tokens.bg, 0.74)
            border.width: 1
            border.color: Qt.alpha(view.panel.online ? Tokens.accent : Tokens.text, view.panel.online ? 0.45 : 0.12)

            IslandText {
              id: badge

              anchors.centerIn: parent
              text: view.panel.badge
              px: 9.5
              color: view.panel.online ? Tokens.accent : Tokens.neutral400
              font.letterSpacing: 1.1
              font.capitalization: Font.AllUppercase
            }
          }

          Item {
            Layout.fillWidth: true
          }

          Segment {
            label: I18n.tr("Map")
            active: !view.listMode
            onClicked: view.listMode = false
          }

          Segment {
            label: I18n.tr("List")
            active: view.listMode
            onClicked: view.listMode = true
          }
        }

        // Busca só na lista: 150 países num espaço de 163px pedem filtro.
        Rectangle {
          Layout.fillWidth: true
          Layout.preferredHeight: 24
          visible: view.listMode
          radius: 7
          color: countryFilter.activeFocus ? Tokens.neutral900 : "transparent"
          border.width: 1
          border.color: countryFilter.activeFocus ? Tokens.accent700 : Tokens.neutral800

          TextInput {
            id: countryFilter

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            color: Tokens.text
            selectionColor: Tokens.accent
            selectedTextColor: Tokens.bg
            font.family: Tokens.fontFamily
            font.pointSize: 11 * 0.75
            clip: true
            onVisibleChanged: if (!visible) text = ""
            Keys.onEscapePressed: {
              text = "";
              focus = false;
            }
          }

          IslandText {
            anchors.left: parent.left
            anchors.leftMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            visible: countryFilter.text === ""
            text: I18n.tr("Search country")
            px: 10.5
            color: Tokens.neutral500
          }
        }

        Item {
          Layout.fillWidth: true
          // Na lista o cartão cresce o que a fileira de atalhos deixa livre.
          Layout.preferredHeight: view.listMode ? map.implicitHeight + 21 : map.implicitHeight

          VpnMap {
            id: map

            anchors.fill: parent
            visible: !view.listMode
            point: view.panel.map.point
          }

          // A lista rola dentro da área do mapa: 163px ≈ seis países por vez,
          // o resto pelo scroll do ponteiro.
          ListView {
            id: countryList

            anchors.fill: parent
            visible: view.listMode
            clip: true
            spacing: 2
            model: view.filteredCountries
            boundsBehavior: Flickable.StopAtBounds

            delegate: Rectangle {
              required property var modelData

              width: countryList.width
              height: 24
              radius: 7
              color: rowPointer.containsMouse ? Tokens.neutral900 : modelData.active ? Tokens.accent900 : "transparent"
              border.width: modelData.active ? 1 : 0
              border.color: Tokens.accent700

              IslandText {
                anchors.left: parent.left
                anchors.leftMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                text: modelData.label
                px: 11
                color: modelData.active ? Tokens.accent100 : rowPointer.containsMouse ? Tokens.text : Tokens.neutral300
                elide: Text.ElideRight
                width: parent.width - 16
              }

              MouseArea {
                id: rowPointer

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: view.vpn.connect(modelData.id)
              }
            }
          }

          // Barra de rolagem fina: sem ela não há pista de que a lista continua.
          Rectangle {
            anchors.right: parent.right
            anchors.rightMargin: 1
            width: 3
            radius: 1.5
            color: Tokens.neutral600
            visible: view.listMode && countryList.contentHeight > countryList.height
            height: Math.max(18, (countryList.height / countryList.contentHeight) * parent.height)
            y: countryList.contentY / Math.max(1, countryList.contentHeight - countryList.height) * (parent.height - height)
          }

          IslandText {
            anchors.centerIn: parent
            visible: view.listMode && view.filteredCountries.length === 0
            text: I18n.tr("Country list unavailable")
            px: 10.5
            color: Tokens.neutral500
          }
        }
      }
    }

    // Atalhos: o país ativo fica realçado pelo `ChoiceButton`. Some na visão
    // de lista, que já mostra todos os países.
    Section {
      visible: !view.listMode

      RowLayout {
        Layout.fillWidth: true
        Layout.preferredHeight: 30
        spacing: 6

        Repeater {
          model: view.panel.quick

          ChoiceButton {
            required property var modelData

            Layout.fillWidth: true
            label: modelData.label
            active: modelData.active
            onClicked: view.vpn.connect(modelData.id)
          }
        }
      }
    }

    // Opções do daemon (`nordvpn settings`), gravadas no próprio NordVPN.
    Section {
      Repeater {
        model: view.panel.options

        SwitchRow {
          required property var modelData

          Layout.fillWidth: true
          Layout.preferredHeight: 24
          label: modelData.label
          on: modelData.on
          onToggled: value => view.vpn.setOption(modelData.id, value)
        }
      }
    }
  }

  // Alternador compacto do cartão geográfico (Peta/Daftar), 22px como no app.
  component Segment: Rectangle {
    id: segment

    required property string label
    property bool active: false

    signal clicked

    implicitWidth: segmentLabel.implicitWidth + 20
    implicitHeight: 22
    radius: 7
    color: active ? Tokens.accent900 : segmentPointer.containsMouse ? Tokens.neutral900 : "transparent"
    border.width: 1
    border.color: active ? Tokens.accent700 : Tokens.neutral800

    Behavior on color {
      ColorAnimation {
        duration: 150
      }
    }

    IslandText {
      id: segmentLabel

      anchors.centerIn: parent
      text: segment.label
      px: 9.5
      color: segment.active ? Tokens.accent100 : segmentPointer.containsMouse ? Tokens.text : Tokens.neutral400
      font.letterSpacing: 0.6
      font.capitalization: Font.AllUppercase
    }

    MouseArea {
      id: segmentPointer

      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: segment.clicked()
    }
  }

  // Divisor (margem 10px 0) seguido do conteúdo da seção, como no `display`.
  component Section: ColumnLayout {
    Layout.fillWidth: true
    spacing: 0

    FadeDivider {
      Layout.fillWidth: true
      Layout.topMargin: 10
      Layout.bottomMargin: 10
    }
  }
}
