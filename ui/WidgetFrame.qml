import QtQuick

// Moldura de widget (specs/16-widgets.md "Pílulas"): 22px, raio 11, padding
// 0 9px, hover `neutral-900` (150ms), mão só se o widget tiver clique.
Rectangle {
  id: frame

  property bool clickable: false
  default property alias content: row.data
  property alias spacing: row.spacing
  // Largura só do conteúdo: quem estende a moldura usa para o próprio
  // `implicitWidth` sem repetir a soma dos filhos da `Row`.
  readonly property real contentWidth: row.implicitWidth

  signal clicked

  implicitWidth: contentWidth + 18
  implicitHeight: 22
  radius: 11
  color: pointer.containsMouse && clickable ? Tokens.neutral900 : "transparent"

  Behavior on color {
    ColorAnimation {
      duration: 150
    }
  }

  MouseArea {
    id: pointer

    anchors.fill: parent
    hoverEnabled: true
    enabled: frame.clickable
    cursorShape: frame.clickable ? Qt.PointingHandCursor : Qt.ArrowCursor
    onClicked: frame.clicked()
  }

  Row {
    id: row

    anchors.verticalCenter: parent.verticalCenter
    x: 9
    spacing: 6
  }
}
