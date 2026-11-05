pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "../core/workspaceIcons.mjs" as IconCore

// Workspaces no estilo do plugin `advanced-workspaces` (MIT, ehlxr), portado
// para a moldura de widget da Island: uma pílula por workspace em uso, com o
// número e o logo real de cada janela aberta nela.
//
// - só os workspaces usados aparecem; o ativo fica fixo mesmo vazio
// - `perMonitor` limita a pílula à barra do monitor onde o workspace vive
// - `showEmpty` completa os números até `maxWorkspaceId`
// - clique foca o workspace (dispatch tipado, sem shell)
//
// O alinhamento vertical usa `RowLayout` + `Layout.alignment` (não âncoras em
// `parent`): os filhos da moldura entram no `Row` dela pelo alias padrão e
// ainda não têm pai quando as âncoras são avaliadas.
WidgetFrame {
  id: widget

  required property var source
  property string screenName: ""
  property bool perMonitor: true
  property bool showEmpty: false
  property bool showIcons: true
  property int maxIcons: 0
  property int maxWorkspaceId: 10
  property int iconSize: 12
  property bool showScratchpad: true
  property string scratchpadName: "special:scratchpad"

  spacing: 3
  implicitHeight: 22

  readonly property bool focused: !widget.source || widget.source.isFocusedMonitor(widget.screenName)

  // Ids visíveis, em ordem. O estado do Hyprland não é reativo por si só, daí
  // a leitura de `revision` no topo (reavalia a cada evento).
  readonly property var workspaceIds: {
    const _ = widget.source ? widget.source.revision : 0;
    if (!widget.source) return [];

    const active = widget.source.activeIdFor(widget.screenName);
    const values = widget.source.workspaces;
    const ids = [];

    for (let i = 0; i < values.length; i++) {
      const ws = values[i];
      const id = ws.id;
      // O teto de `maxWorkspaceId` vale só para os números sintetizados por
      // `showEmpty`: um workspace usado acima dele (12, por exemplo) continua
      // aparecendo.
      if (id <= 0) continue;
      if (String(ws.name || "").indexOf("special:") === 0) continue;

      const owner = widget.source.monitorName(ws);
      if (widget.perMonitor && widget.screenName !== "" && owner !== "" && owner !== widget.screenName) continue;

      if (!widget.showEmpty && !widget.source.hasWindows(ws) && id !== active) continue;
      if (ids.indexOf(id) === -1) ids.push(id);
    }

    if (widget.showEmpty) {
      // Hyprland só reporta workspaces criados; os vazios têm de ser
      // sintetizados. Com `perMonitor`, cada monitor fica com a sua faixa
      // (1-5, 6-10…), que é o layout padrão do Omarchy.
      let first = 1;
      let last = widget.maxWorkspaceId;
      const count = widget.source.monitors.length;
      const index = widget.source.monitorIndex(widget.screenName);
      if (widget.perMonitor && count > 1 && index >= 0) {
        const per = Math.max(1, Math.floor(widget.maxWorkspaceId / count));
        first = index * per + 1;
        last = Math.min(widget.maxWorkspaceId, first + per - 1);
      }
      for (let id = first; id <= last; id++) {
        if (ids.indexOf(id) === -1) ids.push(id);
      }
    }

    ids.sort(function (left, right) { return left - right; });
    return ids;
  }

  readonly property var scratchpad: {
    const _ = widget.source ? widget.source.revision : 0;
    if (!widget.source || !widget.showScratchpad) return null;
    if (String(widget.scratchpadName).indexOf("special:") !== 0) return null;
    const ws = widget.source.workspaceByName(widget.scratchpadName);
    return widget.source.hasWindows(ws) ? ws : null;
  }

  Repeater {
    model: widget.workspaceIds

    delegate: Rectangle {
      id: pill

      required property var modelData

      readonly property bool current: widget.source.activeIdFor(widget.screenName) === pill.modelData
      readonly property var workspace: widget.source.workspaceById(pill.modelData)
      property bool hovered: false

      implicitHeight: 18
      implicitWidth: pillContent.implicitWidth + 12
      height: 18
      width: pillContent.implicitWidth + 12
      radius: 9
      color: pill.current
        ? Qt.alpha(Tokens.accent, widget.focused ? 0.90 : 0.55)
        : pill.hovered ? Tokens.neutral800 : Tokens.neutral900

      Behavior on color {
        ColorAnimation {
          duration: 150
        }
      }

      RowLayout {
        id: pillContent

        anchors.centerIn: parent
        spacing: 2

        IslandText {
          Layout.alignment: Qt.AlignVCenter
          px: 11
          text: String(pill.modelData)
          color: pill.current ? Tokens.bg : Tokens.neutral300
        }

        Repeater {
          model: widget.showIcons ? widget.source.iconsFor(pill.workspace, widget.maxIcons) : []

          delegate: Item {
            id: entry

            required property var modelData

            Layout.alignment: Qt.AlignVCenter
            implicitWidth: widget.iconSize
            implicitHeight: widget.iconSize
            width: widget.iconSize
            height: widget.iconSize

            Rectangle {
              anchors.fill: parent
              visible: entry.modelData.source !== ""
              radius: 3
              color: "transparent"
              clip: true

              Image {
                anchors.fill: parent
                source: entry.modelData.source
                sourceSize: Qt.size(widget.iconSize * 2, widget.iconSize * 2)
                fillMode: Image.PreserveAspectFit
                smooth: true
                asynchronous: true
              }
            }

            IslandText {
              anchors.centerIn: parent
              visible: entry.modelData.source === "" && String(entry.modelData.glyph).charAt(0) === "+"
              px: 10
              text: String(entry.modelData.glyph)
              color: pill.current ? Tokens.bg : Tokens.neutral300
            }

            PhIcon {
              anchors.centerIn: parent
              visible: entry.modelData.source === "" && String(entry.modelData.glyph).charAt(0) !== "+"
              glyph: String(entry.modelData.glyph || IconCore.FALLBACK)
              size: widget.iconSize - 1
              color: pill.current ? Tokens.bg : Tokens.neutral300
            }
          }
        }
      }

      MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: pill.hovered = true
        onExited: pill.hovered = false
        onClicked: widget.source.focusWorkspace(pill.modelData)
      }
    }
  }

  // O scratchpad, quando guarda alguma janela — em qualquer barra, porque ele
  // não pertence a um monitor.
  Rectangle {
    id: scratchPill

    readonly property bool open: !!widget.scratchpad && widget.source.specialOpen(widget.screenName, widget.scratchpadName)
    property bool hovered: false

    visible: widget.scratchpad !== null
    implicitHeight: 18
    implicitWidth: scratchContent.implicitWidth + 12
    height: 18
    width: scratchContent.implicitWidth + 12
    radius: 9
    color: scratchPill.open
      ? Qt.alpha(Tokens.accent, widget.focused ? 0.90 : 0.55)
      : scratchPill.hovered ? Tokens.neutral800 : Tokens.neutral900

    RowLayout {
      id: scratchContent

      anchors.centerIn: parent
      spacing: 2

      IslandText {
        Layout.alignment: Qt.AlignVCenter
        px: 11
        text: "S"
        color: scratchPill.open ? Tokens.bg : Tokens.neutral300
      }

      Repeater {
        model: widget.showIcons && widget.scratchpad ? widget.source.iconsFor(widget.scratchpad, widget.maxIcons) : []

        delegate: Item {
          id: scratchEntry

          required property var modelData

          Layout.alignment: Qt.AlignVCenter
          implicitWidth: widget.iconSize
          implicitHeight: widget.iconSize
          width: widget.iconSize
          height: widget.iconSize

          Rectangle {
            anchors.fill: parent
            visible: scratchEntry.modelData.source !== ""
            radius: 3
            color: "transparent"
            clip: true

            Image {
              anchors.fill: parent
              source: scratchEntry.modelData.source
              sourceSize: Qt.size(widget.iconSize * 2, widget.iconSize * 2)
              fillMode: Image.PreserveAspectFit
              smooth: true
              asynchronous: true
            }
          }

          IslandText {
            anchors.centerIn: parent
            visible: scratchEntry.modelData.source === "" && String(scratchEntry.modelData.glyph).charAt(0) === "+"
            px: 10
            text: String(scratchEntry.modelData.glyph)
            color: scratchPill.open ? Tokens.bg : Tokens.neutral300
          }

          PhIcon {
            anchors.centerIn: parent
            visible: scratchEntry.modelData.source === "" && String(scratchEntry.modelData.glyph).charAt(0) !== "+"
            glyph: String(scratchEntry.modelData.glyph || IconCore.FALLBACK)
            size: widget.iconSize - 1
            color: scratchPill.open ? Tokens.bg : Tokens.neutral300
          }
        }
      }
    }

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onEntered: scratchPill.hovered = true
      onExited: scratchPill.hovered = false
      onClicked: widget.source.toggleSpecial(widget.scratchpadName)
    }
  }
}
