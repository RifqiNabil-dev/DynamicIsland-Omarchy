pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../core/weather.mjs" as WeatherCore

// Modo `weather` (specs/07-clima.md; design v5): padding 14px 16px, cabeçalho
// com o tempo agora · previsão de 4 dias · cidade. A busca usa o geocoding do
// Open-Meteo (sem chave) e a escolha vai para o `settings.json` pelo
// `Service.setWeatherLocation`; sem cidade salva, vale a do Omarchy.
Item {
  id: view

  required property var bar
  readonly property var weather: bar.system.weather
  readonly property var service: bar.service
  readonly property var saved: service !== null ? service.settings.values.weatherLocation : null
  // Sem cidade escolhida aqui, a ilha usa a do Omarchy (`weather.json`, senão a IP).
  readonly property bool automatic: !saved
  // Lugares da última busca: enquanto há lista, ela ocupa o lugar da previsão.
  property var places: []
  readonly property bool picking: places.length > 0

  // Sem `weather.json` o nome só aparece depois da detecção pela área.
  readonly property string placeName: weather.location && weather.location.name !== "" ? weather.location.name : I18n.tr("Weather")

  function search(text) {
    const query = String(text || "").trim();
    if (query === "") {
      places = [];
      return;
    }
    if (geocoder.running) return;
    geocoder.command = ["curl", "-fsS", "--max-time", "8", "--max-filesize", String(WeatherCore.MAX_RESPONSE_BYTES), WeatherCore.geocodingUrl(query, I18n.language)];
    geocoder.running = true;
  }

  function pick(place) {
    if (service) service.setWeatherLocation(place.name, place.latitude, place.longitude);
    places = [];
    field.text = "";
  }

  // Hoje e amanhã pelo índice; o resto pelo dia da semana da data local.
  function dayLabel(day, index) {
    if (index === 0) return I18n.tr("Today");
    if (index === 1) return I18n.tr("Tomorrow");
    return I18n.weekday(new Date(day.date).getDay());
  }

  ColumnLayout {
    anchors.fill: parent
    anchors.leftMargin: 16
    anchors.rightMargin: 16
    anchors.topMargin: 14
    anchors.bottomMargin: 14
    spacing: 0

    PanelHeader {
      Layout.fillWidth: true
      glyph: view.weather.glyph !== "" ? view.weather.glyph : "cloud-sun-fill"
      glyphColor: view.weather.available ? Tokens.accent : Tokens.neutral500
      title: view.placeName
      subtitle: view.weather.available ? I18n.tr(view.weather.condition) : I18n.tr("No data")

      IslandText {
        text: view.weather.temperature !== "" ? view.weather.temperature : "—"
        px: 32
        font.letterSpacing: -0.64
        color: view.weather.stale ? Tokens.neutral400 : Tokens.text
      }
    }

    Section {
      PanelLabel {
        Layout.fillWidth: true
        Layout.bottomMargin: 6
        text: view.picking ? I18n.tr("Pick a city") : I18n.tr("Forecast")
      }

      // Previsão e resultados se revezam no mesmo espaço: a altura do modo é fixa.
      Item {
        Layout.fillWidth: true
        Layout.preferredHeight: 104

        ColumnLayout {
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.top: parent.top
          visible: !view.picking
          spacing: 0

          Repeater {
            model: view.weather.days

            RowLayout {
              id: day

              required property var modelData
              required property int index

              Layout.fillWidth: true
              implicitHeight: 26
              spacing: 8

              IslandText {
                text: view.dayLabel(day.modelData, day.index)
                px: 12.5
                font.weight: Tokens.weightBody
                color: Tokens.neutral300
                Layout.preferredWidth: 72
                elide: Text.ElideRight
              }

              PhIcon {
                glyph: day.modelData.glyph
                size: 15
                color: Tokens.neutral300
              }

              Item {
                Layout.fillWidth: true
              }

              IslandText {
                text: WeatherCore.formatTemperature(day.modelData.max)
                px: 12.5
                font.weight: Tokens.weightBody
                color: Tokens.neutral200
              }

              IslandText {
                text: WeatherCore.formatTemperature(day.modelData.min)
                px: 12.5
                font.weight: Tokens.weightBody
                color: Tokens.neutral500
                Layout.preferredWidth: 34
                horizontalAlignment: Text.AlignRight
              }
            }
          }
        }

        ColumnLayout {
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.top: parent.top
          visible: view.picking
          spacing: 0

          Repeater {
            model: view.places

            ListRow {
              id: place

              required property var modelData

              Layout.fillWidth: true
              implicitHeight: 28
              onClicked: view.pick(place.modelData)

              RowLayout {
                anchors.fill: parent
                spacing: 8

                PhIcon {
                  // `map-pin` não existe em `icons/`: o Phosphor escolhido
                  // para "lugar" é o globo, como no resto do plugin.
                  glyph: "globe-simple"
                  size: 14
                  color: Tokens.neutral400
                }

                IslandText {
                  Layout.fillWidth: true
                  text: place.modelData.name
                  px: 12.5
                  font.weight: Tokens.weightBody
                  color: Tokens.neutral200
                  elide: Text.ElideRight
                }

                IslandText {
                  text: place.modelData.region
                  px: 11
                  font.weight: Tokens.weightBody
                  color: Tokens.neutral500
                  elide: Text.ElideRight
                  Layout.maximumWidth: 180
                }
              }
            }
          }
        }
      }
    }

    Section {
      PanelLabel {
        Layout.fillWidth: true
        Layout.bottomMargin: 6
        text: I18n.tr("Location")
        value: view.placeName
        valueColor: Tokens.neutral300
      }

      Rectangle {
        Layout.fillWidth: true
        implicitHeight: 32
        radius: 9
        color: Tokens.bg
        border.width: 1
        border.color: Tokens.neutral800

        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: 10
          anchors.rightMargin: 10
          spacing: 8

          PhIcon {
            glyph: "cursor-click"
            size: 14
            color: Tokens.neutral400
          }

          TextInput {
            id: field

            Layout.fillWidth: true
            color: Tokens.text
            font.family: Tokens.fontFamily
            font.pointSize: 12.5 * 0.75
            clip: true
            selectByMouse: true
            onAccepted: view.search(text)
            Keys.onEscapePressed: view.places = []
            // O modo abre com a busca à mão: digitar já procura a cidade.
            Component.onCompleted: forceActiveFocus()

            IslandText {
              visible: field.text === ""
              text: I18n.tr("City name")
              px: 12.5
              font.weight: Tokens.weightBody
              color: Tokens.neutral500
              width: field.width
              elide: Text.ElideRight
            }
          }
        }
      }
    }

    RowLayout {
      Layout.fillWidth: true
      Layout.topMargin: 8
      spacing: 6

      TextButton {
        label: I18n.tr("Sync now")
        onClicked: view.weather.refresh()
      }

      Item {
        Layout.fillWidth: true
      }

      // Volta à cidade do Omarchy: nada salvo no `settings.json` da Island.
      TextButton {
        label: I18n.tr("Automatic")
        primary: view.automatic
        opacity: view.automatic ? 0.45 : 1
        onClicked: if (view.service) view.service.clearWeatherLocation()
      }
    }

    Item {
      Layout.fillHeight: true
    }
  }

  Process {
    id: geocoder

    stdout: StdioCollector {
      onStreamFinished: view.places = WeatherCore.parseGeocoding(text)
    }
  }

  // Divisor (margin 10px 0) seguido do conteúdo da seção.
  component Section: ColumnLayout {
    Layout.fillWidth: true
    spacing: 0

    FadeDivider {
      Layout.fillWidth: true
      Layout.topMargin: 10
      Layout.bottomMargin: 10
    }
  }
}
