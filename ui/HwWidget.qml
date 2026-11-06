pragma ComponentBehavior: Bound

import QtQuick
import "../core/hardware.mjs" as HardwareCore

// Widget `hw` (specs/10-hardware.md "Blocos"): blocos de linha única com ícone e valor,
// largura fixa pelo valor mais largo possível (a barra não pula). Sem espaço,
// somem NET → GPU → TEMP (`fittingBlocks`); `budget` é a largura que sobra.
WidgetFrame {
  id: widget

  required property var hardware
  property real budget: 100000

  readonly property real iconSize: 12
  readonly property real blockInnerSpacing: 4

  readonly property var all: hardware.blocks
  readonly property var shownIds: HardwareCore.fittingBlocks(all.map(block => block.id), id => blockWidth(id), budget - 18, widget.spacing)
  // Largura com todos os blocos: a natural. Não pode vir da largura atual,
  // que depende do `budget` dado a partir dela.
  readonly property real fullWidth: all.reduce((sum, block) => sum + blockWidth(block.id), 0) + widget.spacing * Math.max(0, all.length - 1) + 18
  // Largura com só CPU e RAM: o mínimo antes de o widget inteiro sumir.
  readonly property real minWidth: blockWidth("cpu") + blockWidth("ram") + widget.spacing + 18

  clickable: true
  spacing: 6

  function iconForId(id) {
    switch (id) {
      case "cpu": return "cpu";
      case "ram": return "memory";
      case "gpu": return "graphics-card";
      case "temp": return "thermometer-simple";
      case "net": return "arrows-down-up";
      default: return "cpu";
    }
  }

  // Medidas uma vez: mudar o texto do TextMetrics dentro de um binding
  // criaria um laço de binding.
  property var widths: ({})

  function blockWidth(id) {
    return widths[id] || 36;
  }

  Component.onCompleted: {
    const measured = {};
    Object.keys(HardwareCore.WIDEST_VALUE).forEach(id => {
      widest.text = HardwareCore.WIDEST_VALUE[id];
      measured[id] = Math.ceil(iconSize + blockInnerSpacing + widest.advanceWidth) + 2;
    });
    widths = measured;
  }

  TextMetrics {
    id: widest

    font.family: Tokens.fontFamily
    font.pointSize: 11.5 * 0.75
    font.weight: Tokens.weightLabel
    font.features: { "tnum": 1 }
  }

  Repeater {
    model: widget.all.filter(block => widget.shownIds.includes(block.id))

    delegate: Row {
      id: block

      required property var modelData

      width: widget.blockWidth(modelData.id)
      spacing: widget.blockInnerSpacing
      anchors.verticalCenter: parent ? parent.verticalCenter : undefined

      PhIcon {
        anchors.verticalCenter: parent.verticalCenter
        glyph: widget.iconForId(block.modelData.id)
        size: widget.iconSize
        color: block.modelData.tone === "hot" ? Tokens.alertRed : block.modelData.tone === "busy" ? Tokens.accent300 : Tokens.neutral500
      }

      IslandText {
        anchors.verticalCenter: parent.verticalCenter
        text: block.modelData.value
        px: 11.5
        color: block.modelData.tone === "hot" ? Tokens.alertRed : block.modelData.tone === "busy" ? Tokens.accent300 : Tokens.text
      }
    }
  }
}
