pragma ComponentBehavior: Bound

import QtQuick

// Widget de música com modos de exibição personalizáveis (specs/05-musica.md):
// - `compact`: só o título, ondas e o estado de reprodução
// - `full`: título e artista
// - `minimal`: só a capa (ou o ícone do player) com as ondas
// - `controls`: capa/ícone, título, visualizador (ondas) e botões (anterior, tocar/pausar, próxima)
WidgetFrame {
  id: widget

  required property var source
  required property var bar
  property string screenName: ""

  property string mode: "compact"
  property bool showArt: true
  property bool showWaves: true
  property bool hideIdle: false
  property int maxWidth: 140
  property bool compact: false

  readonly property real compactWidth: 32
  readonly property bool active: !!widget.source && widget.source.active
  readonly property bool isPlaying: widget.active && widget.source.playing
  readonly property bool hasArt: widget.active && !!widget.source.artUrl && String(widget.source.artUrl).length > 0
  readonly property bool withControls: widget.mode === "controls"
  readonly property bool withText: widget.mode === "compact" || widget.mode === "full" || widget.mode === "controls"

  readonly property string displayTitle: {
    if (!widget.active) return I18n.tr("Nothing playing");
    const title = widget.source.title || "";
    if (widget.mode === "full" && widget.source.artist && String(widget.source.artist).length > 0) {
      return title.length > 0 ? title + " · " + widget.source.artist : String(widget.source.artist);
    }
    return title.length > 0 ? title : I18n.tr("Nothing playing");
  }

  function openIsland() {
    if (!widget.active) return;
    widget.bar.targetScreen = widget.screenName;
    widget.bar.islandState.toggleMusicPinned();
  }

  visible: !widget.hideIdle || widget.active
  // Em `controls` os botões capturam seus próprios cliques; nos outros modos a moldura inteira abre a Island.
  clickable: !widget.withControls && widget.active
  onClicked: widget.openIsland()

  spacing: 6

  // Botão redondo dos controles: 16px, hover `neutral-900`, apagado quando indisponível.
  component MusicButton: Rectangle {
    id: button

    required property string glyph
    property int iconSize: 10
    property bool available: true

    signal pressed

    width: 16
    height: 16
    implicitWidth: 16
    implicitHeight: 16
    radius: 8
    opacity: button.available ? 1 : 0.35
    color: hover.containsMouse && button.available ? Tokens.neutral900 : "transparent"

    PhIcon {
      anchors.centerIn: parent
      glyph: button.glyph
      size: button.iconSize
      color: hover.containsMouse && button.available ? Tokens.accent : Tokens.text
    }

    MouseArea {
      id: hover

      anchors.fill: parent
      enabled: button.available
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: button.pressed()
    }
  }

  // Capa do álbum, quando o player manda uma e a opção está ligada.
  Item {
    id: artBox

    visible: widget.showArt && widget.hasArt
    width: 16
    height: 16
    implicitWidth: 16
    implicitHeight: 16

    AlbumArt {
      anchors.fill: parent
      radius: 4
      glyphSize: 9
      url: widget.active ? widget.source.artUrl : ""
    }

    MouseArea {
      anchors.fill: parent
      enabled: widget.withControls && widget.active
      cursorShape: Qt.PointingHandCursor
      onClicked: widget.openIsland()
    }
  }

  // Ícone do player (ou nota musical) quando não há capa.
  Item {
    id: iconBox

    visible: !artBox.visible
    width: 14
    height: 16
    implicitWidth: 14
    implicitHeight: 16

    PhIcon {
      anchors.centerIn: parent
      glyph: widget.active ? (widget.source.sourceGlyph || "music-note") : "music-note"
      size: 13
      color: widget.active ? Tokens.accent400 : Tokens.neutral400
    }

    MouseArea {
      anchors.fill: parent
      enabled: widget.withControls && widget.active
      cursorShape: Qt.PointingHandCursor
      onClicked: widget.openIsland()
    }
  }

  // Título (e artista no modo `full`), cortado em `maxWidth`.
  Item {
    id: textBox

    visible: widget.withText
    opacity: widget.compact ? 0 : 1
    width: titleText.width
    height: 16
    implicitWidth: titleText.width
    implicitHeight: 16

    IslandText {
      id: titleText

      anchors.verticalCenter: parent.verticalCenter
      px: 11
      color: widget.active ? Tokens.text : Tokens.neutral400
      text: widget.displayTitle
      elide: Text.ElideRight
      width: Math.min(implicitWidth, widget.maxWidth)
    }

    MouseArea {
      anchors.fill: parent
      enabled: !widget.compact && widget.withControls && widget.active
      cursorShape: Qt.PointingHandCursor
      onClicked: widget.openIsland()
    }
  }

  // Ondas da música (visualizador): visível também no modo `controls`!
  Item {
    id: wavesBox

    visible: widget.showWaves && widget.active
    opacity: widget.compact ? 0 : 1
    width: waves.implicitWidth
    height: 16
    implicitWidth: waves.implicitWidth
    implicitHeight: 16

    MusicWaves {
      id: waves

      anchors.centerIn: parent
      playing: widget.isPlaying
      count: 4
      barHeight: 12
      barWidth: 2
      spacing: 2
    }
  }

  // Estado de reprodução: exibido apenas onde NÃO há botões de controle.
  Item {
    id: statusBox

    visible: !widget.withControls && widget.withText && widget.active
    opacity: widget.compact ? 0 : 1
    width: 12
    height: 16
    implicitWidth: 12
    implicitHeight: 16

    PhIcon {
      anchors.centerIn: parent
      glyph: widget.isPlaying ? "pause-fill" : "play-fill"
      size: 10
      color: Tokens.neutral400
    }
  }

  // Controles inline do modo `controls`: anterior, tocar/pausar, próxima.
  Row {
    id: controlsRow

    visible: widget.withControls && widget.active
    opacity: widget.compact ? 0 : 1
    spacing: 3
    height: 16

    MusicButton {
      glyph: "skip-back-fill"
      available: !!widget.source && (!widget.source.player || widget.source.player.canGoPrevious !== false)
      onPressed: if (widget.active) widget.source.previous()
    }

    MusicButton {
      iconSize: 11
      glyph: widget.isPlaying ? "pause-fill" : "play-fill"
      available: !!widget.source && (!widget.source.player || widget.source.player.canTogglePlaying !== false)
      onPressed: if (widget.active) widget.source.togglePlaying()
    }

    MusicButton {
      glyph: "skip-forward-fill"
      available: !!widget.source && (!widget.source.player || widget.source.player.canGoNext !== false)
      onPressed: if (widget.active) widget.source.next()
    }
  }
}
