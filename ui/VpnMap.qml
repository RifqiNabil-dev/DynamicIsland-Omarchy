pragma ComponentBehavior: Bound

import QtQuick
import "../core/worldMap.mjs" as WorldCore

// Mapa do painel `vpn`: a silhueta equirretangular do Natural Earth vem de
// `core/worldMap.mjs` — gerada por `tools/gen-map-assets.py`, não editar à mão
// — e o marcador do servidor, do ponto que `core/geo.mjs` dá para o país.
//
// Relevo e marcador ficam em Canvas separados: o contorno tem ~4 mil pontos e
// só é recomposto quando o tamanho muda, então o pulso do marcador (a cada
// 40ms) repinta apenas alguns arcos.
Item {
  id: map

  // [lon, lat] do servidor, ou null quando não há conexão.
  required property var point

  property color landColor: Tokens.neutral700
  property color coastColor: Qt.alpha(Tokens.neutral500, 0.45)
  property color markerColor: Tokens.accent
  property color waterColor: Qt.alpha(Tokens.neutral900, 0.55)
  property real phase: 0

  implicitHeight: Math.round(width * WorldCore.mapAspect())

  Timer {
    interval: 40
    repeat: true
    running: map.point !== null && map.point !== undefined
    onTriggered: {
      map.phase = (map.phase + 40 / 2600) % 1;
      overlay.requestPaint();
    }
  }

  Rectangle {
    anchors.fill: parent
    radius: 12
    color: map.waterColor
    border.width: 1
    border.color: Qt.alpha(Tokens.text, 0.08)
  }

  // Relevo: um caminho fechado por polígono da silhueta.
  Canvas {
    id: relief

    anchors.fill: parent
    renderStrategy: Canvas.Cooperative

    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onPaint: {
      const ctx = getContext("2d");
      ctx.clearRect(0, 0, width, height);
      ctx.beginPath();
      const polygons = WorldCore.LAND;
      for (let p = 0; p < polygons.length; p++) {
        const ring = polygons[p];
        for (let i = 0; i < ring.length; i++) {
          const projected = WorldCore.project(ring[i], width, height);
          if (i === 0)
            ctx.moveTo(projected.x, projected.y);
          else
            ctx.lineTo(projected.x, projected.y);
        }
        ctx.closePath();
      }
      ctx.fillStyle = map.landColor;
      ctx.fill();
      ctx.strokeStyle = map.coastColor;
      ctx.lineWidth = 0.6;
      ctx.stroke();
    }
  }

  // Marcador: núcleo, halo e três ondas defasadas saindo do servidor.
  Canvas {
    id: overlay

    anchors.fill: parent
    renderStrategy: Canvas.Cooperative

    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onPaint: {
      const ctx = getContext("2d");
      ctx.clearRect(0, 0, width, height);
      if (!map.point)
        return;
      const projected = WorldCore.project(map.point, width, height);
      for (let i = 0; i < 3; i++) {
        const t = (map.phase + i / 3) % 1;
        ctx.globalAlpha = (1 - t) * 0.5;
        ctx.strokeStyle = map.markerColor;
        ctx.lineWidth = 1.4;
        ctx.beginPath();
        ctx.arc(projected.x, projected.y, 3.5 + t * 24, 0, Math.PI * 2);
        ctx.stroke();
      }
      ctx.globalAlpha = 0.28;
      ctx.fillStyle = map.markerColor;
      ctx.beginPath();
      ctx.arc(projected.x, projected.y, 8, 0, Math.PI * 2);
      ctx.fill();
      ctx.globalAlpha = 1;
      ctx.beginPath();
      ctx.arc(projected.x, projected.y, 3, 0, Math.PI * 2);
      ctx.fill();
    }

    Connections {
      target: map

      function onPointChanged() {
        overlay.requestPaint();
      }
    }
  }
}
