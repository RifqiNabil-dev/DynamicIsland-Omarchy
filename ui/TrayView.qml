pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import "../core/tray.mjs" as TrayCore

// Modo `tray` (specs/16-widgets.md "Bandeja"): o menu do item da bandeja,
// desenhado pela ilha. `QsMenuEntry.display()` abriria um menu *de plataforma* —
// o Quickshell recusa fora do modo QApplication ("Cannot display
// PlatformMenuEntry as quickshell was not started in QApplication mode"), e o
// clique vira no-op silencioso. O menu é montado aqui com `QsMenuOpener`.
// `QsMenuEntry` herda `QsMenuHandle`, então um item com submenu alimenta um
// opener próprio: cada nível da pilha mantém o seu.
Item {
  id: view

  required property var bar

  readonly property var item: bar ? bar.trayItem : null
  readonly property string appTitle: TrayCore.appTitle(item)
  readonly property bool hasMenu: !!item && item.hasMenu === true

  // Um item filho pertence ao modelo do opener do pai: colapsar a pilha num
  // opener só destruiria justamente o item em exibição (submenu vazio). Por isso
  // também se destrói do mais fundo para o mais raso.
  property var submenuStack: []
  readonly property int depth: submenuStack.length
  readonly property var children: depth > 0 ? submenuStack[depth - 1].opener.children : rootOpener.children

  readonly property var rows: {
    const values = children ? children.values : [];
    const list = TrayCore.menuRows(values, depth === 0 ? appTitle : "");
    if (depth === 0)
      return list;
    return [{
        back: true,
        entry: null,
        separator: false,
        text: submenuStack[depth - 1].title,
        enabled: true,
        hasChildren: false,
        checked: false,
        checkable: false
      }].concat(list);
  }
  implicitHeight: TrayCore.panelHeight(rows)

  // A troca de nível reconstrói as linhas na hora, então o item seguinte cai
  // sob um cursor que não se moveu: ignora cliques por um instante, senão o
  // segundo clique de quem achou que o primeiro falhou dispara outra ação.
  property bool settling: false

  function reset() {
    settling = false
    settle.stop()
    const openers = submenuStack
    submenuStack = []
    for (let i = openers.length - 1; i >= 0; i--)
      openers[i].opener.destroy()
  }

  function enter(entry, title) {
    const opener = submenuOpener.createObject(view, { "menu": entry })
    if (!opener)
      return
    const stack = submenuStack.slice()
    stack.push({ "opener": opener, "title": title })
    submenuStack = stack
    settling = true
    settle.restart()
  }

  function leave() {
    if (submenuStack.length === 0)
      return
    const stack = submenuStack.slice()
    const top = stack.pop()
    submenuStack = stack
    top.opener.destroy()
    settling = true
    settle.restart()
  }

  function run(row) {
    if (!row || settling || row.separator)
      return
    if (row.back) {
      leave()
      return
    }
    const entry = row.entry
    if (!entry || !entry.enabled)
      return
    if (row.hasChildren) {
      enter(entry, row.text)
      return
    }
    entry.triggered()
    bar.closeAll()
  }

  Component.onDestruction: reset()

  Timer {
    id: settle

    interval: 250
    onTriggered: view.settling = false
  }

  Component {
    id: submenuOpener

    QsMenuOpener {}
  }

  QsMenuOpener {
    id: rootOpener

    menu: view.hasMenu ? view.item.menu : null
  }

  ColumnLayout {
    anchors.fill: parent
    anchors.leftMargin: TrayCore.TRAY_PADDING
    anchors.rightMargin: TrayCore.TRAY_PADDING
    anchors.topMargin: TrayCore.TRAY_PADDING
    anchors.bottomMargin: TrayCore.TRAY_PADDING
    spacing: TrayCore.TRAY_HEADER_GAP

    PanelHeader {
      Layout.fillWidth: true
      Layout.preferredHeight: TrayCore.TRAY_HEADER_HEIGHT
      glyph: "app-window"
      glyphColor: Tokens.accent
      title: view.appTitle === "" ? I18n.tr("Background app") : view.appTitle
      subtitle: view.depth > 0 ? view.submenuStack[view.depth - 1].title : ""
    }

    Flickable {
      id: list

      Layout.fillWidth: true
      Layout.preferredHeight: TrayCore.listHeight(view.rows)
      visible: view.rows.length > 0
      clip: true
      boundsBehavior: Flickable.StopAtBounds
      contentHeight: column.implicitHeight

      Column {
        id: column

        // No Flickable, `parent` é o contentItem, de largura 0.
        width: list.width

        Repeater {
          model: view.rows

          delegate: Item {
            id: menuRow

            required property var modelData

            readonly property bool separate: modelData.separator === true
            readonly property bool lead: !separate && (modelData.back === true || modelData.checkable === true)

            width: column.width
            height: TrayCore.rowHeight(modelData)

            Rectangle {
              visible: menuRow.separate
              anchors.verticalCenter: parent.verticalCenter
              width: parent.width
              height: 1
              color: Tokens.neutral800
            }

            Rectangle {
              anchors.fill: parent
              visible: !menuRow.separate
              radius: 8
              color: pointer.containsMouse && menuRow.modelData.enabled ? Tokens.neutral900 : "transparent"
            }

            PhIcon {
              id: leadIcon

              anchors.left: parent.left
              anchors.leftMargin: 8
              anchors.verticalCenter: parent.verticalCenter
              visible: menuRow.lead
              glyph: menuRow.modelData.back === true ? "caret-left" : "check-bold"
              size: 13
              color: menuRow.modelData.checked ? Tokens.accent300 : Tokens.neutral400
            }

            IslandText {
              anchors.left: parent.left
              anchors.leftMargin: menuRow.lead ? 29 : 12
              anchors.right: chevron.visible ? chevron.left : parent.right
              anchors.rightMargin: chevron.visible ? 6 : 12
              anchors.verticalCenter: parent.verticalCenter
              visible: !menuRow.separate
              text: menuRow.modelData.text
              elide: Text.ElideRight
              color: menuRow.modelData.enabled ? Tokens.text : Tokens.neutral500
            }

            PhIcon {
              id: chevron

              anchors.right: parent.right
              anchors.rightMargin: 10
              anchors.verticalCenter: parent.verticalCenter
              visible: !menuRow.separate && menuRow.modelData.hasChildren === true
              glyph: "caret-right"
              size: 13
              color: Tokens.neutral400
            }

            MouseArea {
              id: pointer

              anchors.fill: parent
              hoverEnabled: true
              enabled: !menuRow.separate && menuRow.modelData.enabled
              cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
              onClicked: view.run(menuRow.modelData)
            }
          }
        }
      }
    }

    // Item sem menu: o painel existe para dizer isso (e para o cabeçalho
    // continuar sendo o nome do app).
    IslandText {
      Layout.fillWidth: true
      Layout.preferredHeight: TrayCore.TRAY_ROW_HEIGHT
      visible: view.rows.length === 0
      text: I18n.tr("No menu")
      font.weight: Tokens.weightBody
      color: Tokens.neutral400
      horizontalAlignment: Text.AlignHCenter
      verticalAlignment: Text.AlignVCenter
    }
  }
}
