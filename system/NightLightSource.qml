pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

// Modo noturno do Omarchy (hyprsunset). A barra de terceiros recebe um proxy
// do serviço `omarchy.nightlight` por `firstPartyServiceFor`
// (specs/14-spikes.md, S6), com `enabled` e `toggle()` ao vivo. Fora do
// omarchy-shell (harness `dev/`) não há serviço e o tile some.
Scope {
  id: nightLight

  property var shell: null
  readonly property var service: shell && typeof shell.firstPartyServiceFor === "function"
    ? shell.firstPartyServiceFor("omarchy.nightlight") : null
  readonly property bool available: service !== null
  readonly property bool on: available && service.enabled === true

  function toggle() {
    if (!available) return;
    // O proxy de `firstPartyServiceFor` não expõe `toggle()`: o contrato de
    // `/usr/share/omarchy/shell/services/PluginFirstPartyServiceApi.qml` é
    // `enabled` (leitura) + `setNightlight(bool)` (escrita). Chamar
    // `service.toggle()` levanta TypeError e o modo noturno nunca liga.
    if (typeof service.setNightlight === "function") {
      service.setNightlight(!on);
      return;
    }
    // Serviço direto (harness `dev/`), que tem `toggle()`.
    if (typeof service.toggle === "function") service.toggle();
  }
}
