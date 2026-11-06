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
  property bool perMonitor: false
  property bool showEmpty: false
  property bool showIcons: true
  property int maxIcons: 0
  property int maxWorkspaceId: 10
  property int iconSize: 12
  property bool showScratchpad: true
  property string scratchpadName: "special:scratchpad"
  // Numeração global (como o Omarchy Linux default): cada barra mostra o id
  // real do Hyprland, então workspace 1 é "1" em todos os monitores.
  property bool localNumbers: false
  property int perMonitorIds: 0
  // Espaço entre dois logos na pílula (para não se encostarem).
  property int iconGap: 4
  // Texto da pílula do scratchpad; `""` deixa só os ícones.
  property string scratchpadLabel: "S"

  spacing: 3
  implicitHeight: 22

  readonly property bool focused: !widget.source || widget.source.isFocusedMonitor(widget.screenName)

  // Numeração local por faixas: a barra de cada monitor conta a partir de 1 na
  // faixa de ids onde os seus workspaces vivem, então dois monitores aparecem na
  // mesma escala (1-5 e 1-5) em vez de 1-3 de um lado e 12 do outro.
  //
  // `perMonitorIds` > 0 fixa o tamanho da faixa; 0 divide `maxWorkspaceId` pelo
  // número de monitores.
  readonly property int bankSize: {
    const count = widget.source ? Math.max(1, widget.source.monitors.length) : 1;
    if (widget.perMonitorIds > 0) return widget.perMonitorIds;
    return Math.max(1, Math.ceil(widget.maxWorkspaceId / count));
  }

  /** Primeiro id da faixa deste monitor: o bloco que contém o menor id dele. */
  readonly property int bankFirst: {
    const _ = widget.source ? widget.source.revision : 0;
    if (!widget.source || !widget.perMonitor) return 1;
    const size = widget.bankSize;
    let anchor = -1;
    const values = widget.source.workspaces;
    for (let i = 0; i < values.length; i++) {
      const ws = values[i];
      if (ws.id <= 0) continue;
      if (String(ws.name || "").indexOf("special:") === 0) continue;
      if (widget.source.monitorName(ws) !== widget.screenName) continue;
      if (anchor < 0 || ws.id < anchor) anchor = ws.id;
    }
    // Sem workspace vivo, a faixa sai da posição do monitor na lista.
    if (anchor < 0) {
      const index = Math.max(0, widget.source.monitorIndex(widget.screenName));
      anchor = index * size + 1;
    }
    return size * Math.floor((anchor - 1) / size) + 1;
  }

  /** Número mostrado na pílula: id global, ou a contagem local da barra. */
  function labelFor(id) {
    const value = Number(id);
    if (!widget.localNumbers) return String(value);
    if (widget.perMonitor) return String(value - widget.bankFirst + 1);
    const per = Math.max(1, widget.perMonitorIds > 0 ? widget.perMonitorIds : widget.maxWorkspaceId);
    return String(((value - 1) % per + per) % per + 1);
  }

  function isWorkspaceVisibleOnOther(wsId) {
    if (!widget.source) return false;
    const monitors = widget.source.monitors;
    for (let i = 0; i < monitors.length; i++) {
      if (String(monitors[i].name) === widget.screenName) continue;
      if (monitors[i].activeWorkspace && monitors[i].activeWorkspace.id === wsId) return true;
    }
    return false;
  }

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

      // Em modo global (`perMonitor: false`) a pílula mostra o workspace em
      // qualquer monitor; só filtra por monitor quando `perMonitor` está ativo.
      const owner = widget.source.monitorName(ws);
      if (widget.perMonitor && widget.screenName !== "" && owner !== "" && owner !== widget.screenName) continue;

      // Em modo global não escondemos um workspace só porque não tem janela
      // neste monitor: ele pode estar ativo em outro. Em modo por-monitor,
      // escondemos os vazios que não são o ativo desta barra.
      if (!widget.showEmpty && !widget.source.hasWindows(ws) && id !== active) {
        if (widget.perMonitor) continue;
        // Global: só esconde se também não for o workspace focado em lugar
        // nenhum (não há como saber sem monitor, então mantemos visível).
      }
      if (ids.indexOf(id) === -1) ids.push(id);
    }

    if (widget.showEmpty) {
      // Hyprland só reporta workspaces criados; os vazios têm de ser
      // sintetizados. Com `perMonitor` a faixa é a deste monitor (a mesma que
      // numera as pílulas), então as duas barras mostram a mesma contagem.
      const first = widget.perMonitor ? widget.bankFirst : 1;
      const last = widget.perMonitor ? first + widget.bankSize - 1 : widget.maxWorkspaceId;
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
      readonly property bool onOther: !pill.current && widget.isWorkspaceVisibleOnOther(pill.modelData)
      readonly property var workspace: widget.source.workspaceById(pill.modelData)
      property bool hovered: false

      implicitHeight: 18
      implicitWidth: pillContent.implicitWidth + 12
      height: 18
      width: pillContent.implicitWidth + 12
      radius: 9
      color: pill.current
        ? Qt.alpha(Tokens.accent, widget.focused ? 0.90 : 0.55)
        : pill.onOther
          ? Qt.alpha(Tokens.accent, 0.22)
          : pill.hovered ? Tokens.neutral800 : Tokens.neutral900
      border.width: pill.onOther ? 1 : 0
      border.color: pill.onOther ? Qt.alpha(Tokens.accent, 0.45) : "transparent"

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
          text: widget.labelFor(pill.modelData)
          color: pill.current ? Tokens.bg : pill.onOther ? Tokens.neutral100 : Tokens.neutral300
        }

        RowLayout {
          Layout.alignment: Qt.AlignVCenter
          spacing: widget.iconGap

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
        text: widget.scratchpadLabel
        visible: widget.scratchpadLabel !== ""
        color: scratchPill.open ? Tokens.bg : Tokens.neutral300
      }

      RowLayout {
        Layout.alignment: Qt.AlignVCenter
        spacing: widget.iconGap

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
