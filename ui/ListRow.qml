pragma ComponentBehavior: Bound

import QtQuick

// Linha das listas de `wifi` e `bt`: raio 10, padding 0 8px, fundo
// `accent-900` quando ativa, hover `neutral-900` nas outras.
Rectangle {
  id: row

  property bool active: false
  default property alias content: inner.data

  signal clicked

  // The row's click area sits *under* the content, not on top: that way a
  // child with its own `MouseArea` (the forget button in `DeviceRow`) gets the
  // click, and hover stays the row's because that button leaves
  // `hoverEnabled` off.
  readonly property alias hovered: pointer.containsMouse

  radius: 10
  color: active ? Tokens.accent900 : pointer.containsMouse ? Tokens.neutral900 : "transparent"

  MouseArea {
    id: pointer

    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: row.clicked()
  }

  Item {
    id: inner

    anchors.fill: parent
    anchors.leftMargin: 8
    anchors.rightMargin: 8
  }
}
