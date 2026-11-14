pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "../core/osd.mjs" as OsdCore

// Painel `quick` no formato control center (referência do usuário): duas
// fileiras de pílulas grandes — rádios e modos — e o cartão "Controls" com os
// sliders verticais de volume, microfone e brilho ao lado da grade de ações.
// Substitui a `ControlsRow` de 46px só em `quick`; `wifi`/`bt` continuam com
// a fileira antiga.
Item {
  id: panel

  required property var bar
  readonly property var system: bar.system
  readonly property var audio: system.audio

  // 414 = 14 (respiro) + 72 + 10 + 72 + 10 + 222 (cartão) + 14.
  implicitWidth: 660
  implicitHeight: 414

  readonly property int pad: 14
  readonly property int gap: 10

  /** Valor de um bloco do widget de hardware (`cpu`, `temp`), ou o padrão. */
  function hwValue(id, fallback) {
    const blocks = system.hardware.blocks || [];
    for (const block of blocks) if (block && block.id === id) return String(block.value);
    return fallback;
  }

  // Pílula grande (72px): círculo do ícone, título, estado e chevron. Ligada,
  // o círculo fica branco e o ícone escuro — o realce do design de referência.
  component PanelPill: Rectangle {
    id: pill

    required property string glyph
    property string title: ""
    property string subtitle: ""
    property bool on: false
    property bool chevron: false
    property bool interactive: true

    signal clicked

    readonly property bool hovered: pointer.containsMouse

    implicitHeight: 72
    radius: 20
    color: pill.hovered && pill.interactive ? Tokens.neutral700 : Tokens.tileOff

    Behavior on color {
      ColorAnimation {
        duration: 160
      }
    }

    RowLayout {
      anchors.fill: parent
      anchors.leftMargin: 14
      anchors.rightMargin: 14
      spacing: 12

      Rectangle {
        implicitWidth: 44
        implicitHeight: 44
        radius: 22
        color: pill.on ? Tokens.neutral100 : Qt.alpha(Tokens.text, 0.09)

        PhIcon {
          anchors.centerIn: parent
          glyph: pill.glyph
          size: 20
          color: pill.on ? Tokens.neutral900 : Tokens.neutral100
        }
      }

      ColumnLayout {
        Layout.fillWidth: true
        spacing: 1

        IslandText {
          Layout.fillWidth: true
          text: pill.title
          px: 15
          elide: Text.ElideRight
        }

        IslandText {
          Layout.fillWidth: true
          visible: pill.subtitle !== ""
          text: pill.subtitle
          px: 12
          color: Tokens.neutral400
          font.weight: Tokens.weightBody
          elide: Text.ElideRight
        }
      }

      PhIcon {
        visible: pill.chevron
        glyph: "caret-right"
        size: 14
        color: Tokens.neutral400
      }
    }

    MouseArea {
      id: pointer

      anchors.fill: parent
      enabled: pill.interactive
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: pill.clicked()
    }
  }

  // Botão redondo de 72px ao lado das pílulas (Configurações e Energia).
  component RoundAction: Rectangle {
    id: action

    required property string glyph

    signal clicked

    readonly property bool hovered: pointer.containsMouse

    implicitWidth: 72
    implicitHeight: 72
    radius: 36
    color: action.hovered ? Tokens.neutral700 : Tokens.tileOff

    Behavior on color {
      ColorAnimation {
        duration: 160
      }
    }

    PhIcon {
      anchors.centerIn: parent
      glyph: action.glyph
      size: 22
      color: Tokens.neutral200
    }

    MouseArea {
      id: pointer

      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: action.clicked()
    }
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

    // Fileira 1: rádios conectados e Configurações.
    RowLayout {
      Layout.fillWidth: true
      spacing: panel.gap

      PanelPill {
        Layout.fillWidth: true
        visible: panel.system.wifi.available
        glyph: panel.system.wifi.radioOn ? "wifi-high-bold" : "wifi-slash-bold"
        title: I18n.tr("Wi-Fi")
        subtitle: {
          const active = panel.system.wifi.active;
          if (!panel.system.wifi.radioOn) return I18n.tr("Off");
          return active !== null && active.ssid ? String(active.ssid) : I18n.tr("Not connected");
        }
        on: panel.system.wifi.radioOn
        chevron: true
        onClicked: panel.bar.openFromBar(panel.bar.targetScreen, panel.bar.mode === "wifi" ? "quick" : "wifi")
      }

      PanelPill {
        Layout.fillWidth: true
        visible: panel.system.bluetooth.available
        glyph: "bluetooth-bold"
        title: I18n.tr("Bluetooth")
        subtitle: panel.system.bluetooth.radioOn ? I18n.tr("On") : I18n.tr("Off")
        on: panel.system.bluetooth.radioOn
        chevron: true
        onClicked: panel.bar.openFromBar(panel.bar.targetScreen, panel.bar.mode === "bt" ? "quick" : "bt")
      }

      RoundAction {
        glyph: "gear-six"
        // Fecha antes de abrir: com o foco exclusivo da ilha, o menu não o pegaria.
        onClicked: {
          panel.bar.closeAll();
          panel.system.session.openSettings();
        }
      }
    }

    // Fileira 2: modos e Energia.
    RowLayout {
      Layout.fillWidth: true
      spacing: panel.gap

      PanelPill {
        Layout.fillWidth: true
        visible: panel.bar.service !== null
        glyph: panel.bar.service !== null && panel.bar.service.doNotDisturb ? "bell-slash-fill" : "bell-fill"
        title: I18n.tr("Focus")
        subtitle: panel.bar.service !== null && panel.bar.service.doNotDisturb ? I18n.tr("On") : I18n.tr("Off")
        on: panel.bar.service !== null && panel.bar.service.doNotDisturb
        onClicked: if (panel.bar.service) panel.bar.service.setDoNotDisturb(!panel.bar.service.doNotDisturb)
      }

      PanelPill {
        Layout.fillWidth: true
        visible: panel.system.nightLight.available
        glyph: "moon-stars"
        title: I18n.tr("Night light")
        subtitle: panel.system.nightLight.on ? I18n.tr("On") : I18n.tr("Off")
        on: panel.system.nightLight.on
        onClicked: panel.system.nightLight.toggle()
      }

      RoundAction {
        glyph: "power-bold"
        onClicked: panel.bar.islandState.togglePower()
      }
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
                  label: panel.audio.sinkLabel !== "" ? panel.audio.sinkLabel : I18n.tr("Output")
                  chevron: true
                  onClicked: panel.bar.openFromBar(panel.bar.targetScreen, "mixer")
                }

                MiniPill {
                  Layout.fillWidth: true
                  Layout.preferredWidth: 150
                  glyph: "microphone-fill"
                  label: panel.audio.sourceLabel !== "" ? panel.audio.sourceLabel : I18n.tr("Input")
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
