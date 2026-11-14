pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "../core/osd.mjs" as OsdCore

// Painel `quick` no formato control center (referência do usuário): o
// cabeçalho `QuickHeader` — rádios e modos — sobre o cartão "Controls", com os
// sliders verticais de volume, microfone e brilho ao lado da grade de ações.
Item {
  id: panel

  required property var bar
  readonly property var system: bar.system
  readonly property var audio: system.audio

  // 406 = 14 (respiro) + 146 (cabeçalho) + 10 + 222 (cartão) + 14.
  implicitWidth: 660
  implicitHeight: 406

  readonly property int pad: 14
  readonly property int gap: 10

  /** Valor de um bloco do widget de hardware (`cpu`, `temp`), ou o padrão. */
  function hwValue(id, fallback) {
    const blocks = system.hardware.blocks || [];
    for (const block of blocks) if (block && block.id === id) return String(block.value);
    return fallback;
  }

  // Pílula pequena (40px) da grade: ícone, rótulo e chevron opcional. Ativa,
  // fica branca com a tinta escura (o "Awake" da referência).
  component MiniPill: Rectangle {
    id: mini

    required property string glyph
    property string label: ""
    property bool active: false
    property bool chevron: false
    property bool interactive: true
    property color activeColor: Tokens.neutral100
    property color activeInk: Tokens.neutral900

    signal clicked

    readonly property bool hovered: pointer.containsMouse

    implicitHeight: 40
    radius: 20
    color: mini.active ? mini.activeColor : mini.hovered && mini.interactive ? Tokens.neutral700 : Qt.alpha(Tokens.text, 0.07)

    Behavior on color {
      ColorAnimation {
        duration: 160
      }
    }

    RowLayout {
      anchors.fill: parent
      anchors.leftMargin: 12
      anchors.rightMargin: 12
      spacing: 7

      PhIcon {
        glyph: mini.glyph
        size: 14
        color: mini.active ? mini.activeInk : Tokens.neutral200
      }

      IslandText {
        Layout.fillWidth: true
        text: mini.label
        px: 12.5
        elide: Text.ElideRight
        color: mini.active ? mini.activeInk : Tokens.text
      }

      PhIcon {
        visible: mini.chevron
        glyph: "caret-right"
        size: 12
        color: mini.active ? mini.activeInk : Tokens.neutral500
      }
    }

    MouseArea {
      id: pointer

      anchors.fill: parent
      enabled: mini.interactive
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: mini.clicked()
    }
  }

  ColumnLayout {
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.margins: panel.pad
    spacing: panel.gap

    QuickHeader {
      Layout.fillWidth: true
      bar: panel.bar
    }

    // Cartão "Controls": sliders verticais à esquerda, grade de ações à direita.
    Rectangle {
      id: card

      Layout.fillWidth: true
      Layout.preferredHeight: 222
      radius: 20
      color: Tokens.neutral900

      ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        IslandText {
          text: I18n.tr("Controls")
          px: 13
          color: Tokens.neutral400
          font.weight: Tokens.weightBody
        }

        RowLayout {
          Layout.fillWidth: true
          Layout.fillHeight: true
          spacing: 22

          RowLayout {
            spacing: 16

            VSlider {
              glyph: OsdCore.volumeGlyph(panel.audio.percent, panel.audio.muted)
              value: panel.audio.percent
              onMoved: value => panel.audio.setPercent(value)
              onDragStarted: panel.bar.islandState.dragStart()
              onDragEnded: panel.bar.islandState.dragEnd()
            }

            VSlider {
              glyph: panel.audio.micMuted ? "microphone-slash-fill" : "microphone-fill"
              value: panel.audio.micPercent
              onMoved: value => panel.audio.setMicPercent(value)
              onDragStarted: panel.bar.islandState.dragStart()
              onDragEnded: panel.bar.islandState.dragEnd()
            }

            VSlider {
              visible: panel.system.brightness.available
              glyph: "sun-fill"
              value: panel.system.brightness.percent
              onMoved: value => panel.system.brightness.setPercent(value)
              onDragStarted: panel.bar.islandState.dragStart()
              onDragEnded: panel.bar.islandState.dragEnd()
            }
          }

          Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            ColumnLayout {
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              spacing: 8

              RowLayout {
                Layout.fillWidth: true
                spacing: 8

                MiniPill {
                  Layout.fillWidth: true
                  Layout.preferredWidth: 150
                  glyph: "speaker-high-fill"
                  // Prefixo distingue saída de entrada: os dois dispositivos
                  // costumam ter o mesmo `description` do PipeWire.
                  label: panel.audio.sinkLabel !== "" ? I18n.tr("Output") + " · " + panel.audio.sinkLabel : I18n.tr("Output")
                  chevron: true
                  onClicked: panel.bar.openFromBar(panel.bar.targetScreen, "mixer")
                }

                MiniPill {
                  Layout.fillWidth: true
                  Layout.preferredWidth: 150
                  glyph: "microphone-fill"
                  label: panel.audio.sourceLabel !== "" ? I18n.tr("Input") + " · " + panel.audio.sourceLabel : I18n.tr("Input")
                  chevron: true
                  onClicked: panel.bar.openFromBar(panel.bar.targetScreen, "mixer")
                }
              }

              RowLayout {
                Layout.fillWidth: true
                spacing: 8

                MiniPill {
                  Layout.fillWidth: true
                  Layout.preferredWidth: 100
                  glyph: panel.system.weather.glyph !== "" ? panel.system.weather.glyph : "cloud-sun-fill"
                  label: panel.system.weather.available ? panel.system.weather.temperature : I18n.tr("Weather")
                  interactive: panel.system.weather.available
                  onClicked: panel.bar.openFromBar(panel.bar.targetScreen, "weather")
                }

                MiniPill {
                  Layout.fillWidth: true
                  Layout.preferredWidth: 100
                  glyph: "cpu"
                  label: panel.hwValue("temp", "") !== "" ? panel.hwValue("cpu", "0%") + " · " + panel.hwValue("temp", "") : panel.hwValue("cpu", "—")
                  interactive: false
                }

                MiniPill {
                  Layout.fillWidth: true
                  Layout.preferredWidth: 100
                  glyph: panel.system.screenRecord.recording ? "stop-fill" : "record-fill"
                  label: I18n.tr("Record")
                  active: panel.system.screenRecord.recording
                  activeColor: Tokens.recordOnBg
                  activeInk: Tokens.neutral100
                  onClicked: {
                    if (!panel.system.screenRecord.recording) panel.bar.closeAll();
                    panel.system.screenRecord.toggle();
                  }
                }
              }

              RowLayout {
                Layout.fillWidth: true
                spacing: 8

                MiniPill {
                  Layout.fillWidth: true
                  Layout.preferredWidth: 100
                  visible: panel.system.idle.available
                  glyph: "coffee-fill"
                  label: I18n.tr("Awake")
                  active: panel.system.idle.stayAwake
                  onClicked: panel.system.idle.toggle()
                }

                MiniPill {
                  Layout.fillWidth: true
                  Layout.preferredWidth: 100
                  glyph: "monitor"
                  label: I18n.tr("Display")
                  onClicked: panel.bar.openFromBar(panel.bar.targetScreen, "display")
                }

                MiniPill {
                  Layout.fillWidth: true
                  Layout.preferredWidth: 100
                  visible: panel.system.dictation.available
                  glyph: panel.system.dictation.recording ? "microphone-fill" : "microphone"
                  label: I18n.tr("Dictation")
                  active: panel.system.dictation.recording
                  onClicked: panel.system.dictation.toggle()
                }
              }
            }
          }
        }
      }
    }
  }
}
