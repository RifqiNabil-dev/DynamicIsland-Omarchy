pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Window
import "../core/tray.mjs" as TrayCore

// Widget `tray` (specs/16-widgets.md "Bandeja"): um ícone por app na bandeja.
// Clique esquerdo mostra a janela (`activate()`), direito abre o menu do app no
// modo `tray`; app que só tem menu (`onlyMenu`) abre o menu nos dois.
WidgetFrame {
  id: widget

  required property var source
  required property var bar
  required property string screenName
  property bool compact: false

  readonly property var items: source && source.items ? source.items : []
  readonly property int iconSize: 16
  readonly property int iconGap: 6
  // Colapsado (spec 16): sobra o primeiro ícone com o padding da pílula.
  readonly property real compactWidth: items.length > 0 ? iconSize + 18 : 0

  implicitWidth: {
    const shown = compact ? Math.min(items.length, 1) : items.length;
    return shown > 0 ? shown * iconSize + (shown - 1) * iconGap + 18 : 0;
  }
  visible: items.length > 0
  clickable: false
  spacing: iconGap

  function openMenu(item) {
    bar.trayItem = item;
    bar.openFromBar(screenName, "tray");
  }

  Repeater {
    model: widget.compact ? widget.items.slice(0, 1) : widget.items

    delegate: Item {
      id: cell

      required property var modelData

      width: widget.iconSize
      height: widget.iconSize

      Rectangle {
        anchors.fill: parent
        anchors.margins: -4
        radius: 4
        color: hover.containsMouse ? Tokens.neutral800 : "transparent"
      }

      Image {
        id: appIcon

        // `image://` montado pelo Quickshell a partir do pixmap/nome de tema do
        // item; qualquer outro esquema volta vazio e cai no glifo.
        readonly property real density: Screen.devicePixelRatio * Tokens.zoomFor(Screen.width, Screen.height)
        readonly property bool ready: status === Image.Ready

        anchors.fill: parent
        source: TrayCore.iconSource(cell.modelData.icon)
        sourceSize: Qt.size(Math.ceil(width * density), Math.ceil(height * density))
        fillMode: Image.PreserveAspectFit
        smooth: true
        visible: false
        layer.enabled: true
        layer.textureSize: sourceSize
      }

      // Ícone `-symbolic` é de uma cor só: tinge com a cor do texto como o
      // `PhIcon`. Pixmap colorido (Vesktop) passa direto (`colorization: 0`).
      MultiEffect {
        anchors.fill: appIcon
        source: appIcon
        visible: appIcon.ready
        colorization: TrayCore.isSymbolic(cell.modelData.icon) ? 1 : 0
        colorizationColor: Tokens.text
      }

      PhIcon {
        anchors.centerIn: parent
        visible: !appIcon.ready
        glyph: "app-window"
        size: widget.iconSize - 2
        color: Tokens.neutral400
      }

      MouseArea {
        id: hover

        anchors.fill: parent
        anchors.margins: -4
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => {
          if (mouse.button === Qt.RightButton) {
            if (cell.modelData.hasMenu)
              widget.openMenu(cell.modelData);
            return;
          }
          if (mouse.button === Qt.MiddleButton) {
            widget.source.secondary(cell.modelData);
            return;
          }
          // Só-menu: o clique esquerdo do app é o próprio menu.
          if (cell.modelData.onlyMenu && cell.modelData.hasMenu)
            widget.openMenu(cell.modelData);
          else
            widget.source.activate(cell.modelData);
        }
      }
    }
  }
}
