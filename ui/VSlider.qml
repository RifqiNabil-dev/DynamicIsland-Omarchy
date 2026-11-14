pragma ComponentBehavior: Bound

import QtQuick

// Slider vertical do painel `quick` (design: barra "Controls" do control
// center): trilho 70×160 raio 18, preenchimento `neutral-100` crescendo de
// baixo para cima, ícone no pé e porcentagem no topo. Texto e ícone trocam
// de tinta quando o preenchimento passa por baixo deles.
Item {
  id: slider

  required property string glyph
  property int value: 0
  property bool interactive: true

  signal moved(int value)
  signal dragStarted
  signal dragEnded

  readonly property bool dragging: pointer.pressed
  property int dragValue: 0
  readonly property int shownValue: dragging ? dragValue : Math.max(0, Math.min(100, value))
  readonly property real fillHeight: track.height * shownValue / 100

  implicitWidth: 70
  implicitHeight: 160
  activeFocusOnTab: interactive

  Rectangle {
    id: track

    anchors.fill: parent
    radius: 18
    color: Qt.alpha(Tokens.text, 0.05)

    Rectangle {
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      height: slider.fillHeight
      radius: Math.min(18, height / 2)
      color: Tokens.neutral100

      Behavior on height {
        enabled: !slider.dragging
        NumberAnimation {
          duration: Tokens.fadeMs
          easing.type: Easing.OutQuad
        }
      }
    }
  }

  IslandText {
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.top: parent.top
    anchors.topMargin: 12
    text: slider.shownValue + "%"
    px: 12
    // O topo só está coberto num valor quase cheio.
    color: slider.fillHeight > track.height - 34 ? Tokens.neutral900 : Tokens.neutral300
  }

  PhIcon {
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: 13
    glyph: slider.glyph
    size: 22
    color: slider.fillHeight > 45 ? Tokens.neutral900 : Tokens.neutral200
  }

  MouseArea {
    id: pointer

    anchors.fill: parent
    enabled: slider.interactive
    preventStealing: true
    cursorShape: Qt.PointingHandCursor
    onPressed: mouse => {
      slider.forceActiveFocus();
      slider.dragStarted();
      slider.pointTo(mouse.y);
    }
    onPositionChanged: mouse => slider.pointTo(mouse.y)
    onReleased: slider.dragEnded()
    onCanceled: slider.dragEnded()
    onWheel: wheel => {
      const delta = wheel.angleDelta.y > 0 ? 3 : -3;
      slider.moved(Math.max(0, Math.min(100, slider.shownValue + delta)));
      wheel.accepted = true;
    }
  }

  function pointTo(y) {
    dragValue = Math.round(Math.max(0, Math.min(1, 1 - y / track.height)) * 100);
    moved(dragValue);
  }

  function step(delta) {
    moved(Math.max(0, Math.min(100, value + delta)));
  }

  Keys.onUpPressed: step(5)
  Keys.onDownPressed: step(-5)
}
