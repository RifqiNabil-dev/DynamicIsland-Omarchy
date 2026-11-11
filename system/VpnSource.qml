pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import "../core/vpn.mjs" as VpnCore

// NordVPN: `nordvpn status`/`nordvpn settings` no relógio do widget, as taxas
// pelo delta de `Transfer:` entre polls (o cliente Linux do NordVPN roda o
// NordLynx em namespace próprio: não há interface de túnel no host, logo
// `/sys/class/net/nordlynx` não existe) e a latência por um ping quando o
// painel está aberto. Só roda com o widget no ambiente ativo ou com o painel
// aberto (specs/16-widgets.md), como as outras fontes de widget.
Scope {
  id: vpn

  property bool polling: false
  property bool panelOpen: false

  property var state: ({
      status: "",
      connected: false,
      connecting: false,
      loggedIn: true,
      hostname: "",
      country: "",
      city: "",
      serverIp: "",
      technology: "",
      protocol: "",
      transferIn: null,
      transferOut: null,
      uptime: ""
    })
  property var options: ({
      killSwitch: false,
      autoConnect: false,
      protocol: "",
      firewall: false
    })
  property var rates: ({
      down: 0,
      up: 0
    })
  property int latency: -1
  // `nordvpn countries`: os ~150 países que o daemon aceita; alimenta a lista
  // do painel (lida uma vez, não entra no relógio do poll).
  property var countries: []
  // Sem o CLI o widget não faz sentido: o painel diz o motivo.
  property bool installed: true

  readonly property bool connected: state.connected === true
  readonly property bool connecting: state.connecting === true

  // Última leitura de `Transfer:` (bytes) e o instante dela.
  property real lastIn: -1
  property real lastOut: -1
  property double lastMs: 0

  onPollingChanged: if (polling) {
    refresh();
    refreshCountries();
  }
  onPanelOpenChanged: if (panelOpen) refreshCountries()
  onConnectedChanged: {
    latency = -1;
    lastIn = -1;
    lastOut = -1;
    lastMs = 0;
    if (!connected) rates = ({
        down: 0,
        up: 0
      });
  }

  function refresh() {
    if (!statusProc.running) statusProc.running = true;
    if (!settingsProc.running) settingsProc.running = true;
  }

  // A lista de países só muda com o daemon: uma leitura basta por sessão.
  function refreshCountries() {
    if (installed && countries.length === 0 && !countriesProc.running) countriesProc.running = true;
  }

  function applyStatus(text) {
    const next = VpnCore.parseStatus(text);
    if (next.status === "" && next.loggedIn === true && String(text).trim() === "") return;
    const now = Date.now();
    const hadCounters = lastIn >= 0 && lastMs > 0;
    state = next;
    if (!next.connected || next.transferIn === null || next.transferOut === null) {
      lastIn = -1;
      lastOut = -1;
      lastMs = 0;
      rates = ({
          down: 0,
          up: 0
        });
      return;
    }
    // Contadores por sessão: se caíram (reconexão) a base recomeça em vez de
    // inventar um pico negativo.
    if (hadCounters && now > lastMs && next.transferIn >= lastIn && next.transferOut >= lastOut)
      rates = VpnCore.rates(lastIn, lastOut, next.transferIn, next.transferOut, (now - lastMs) / 1000);
    lastIn = next.transferIn;
    lastOut = next.transferOut;
    lastMs = now;
  }

  // Uma ação por vez: o daemon do NordVPN serializa os comandos do CLI.
  function runAction(command) {
    if (actionProc.running) return;
    actionProc.command = command;
    actionProc.running = true;
  }

  // Sem país, conecta ao melhor servidor; com país, usa o token do CLI (atalho
  // ou qualquer país da lista).
  function connect(country) {
    const target = VpnCore.isCountryToken(country) ? country : "";
    runAction(target === "" ? ["nordvpn", "connect"] : ["nordvpn", "connect", target]);
  }

  function disconnect() {
    runAction(["nordvpn", "disconnect"]);
  }

  function toggle() {
    if (connected) disconnect();
    else connect("");
  }

  function setOption(id, on) {
    if (id === "killSwitch") runAction(["nordvpn", "set", "killswitch", on ? "on" : "off"]);
    else if (id === "autoConnect") runAction(["nordvpn", "set", "autoconnect", on ? "on" : "off"]);
  }

  Process {
    id: statusProc

    command: ["nordvpn", "status"]
    stdout: StdioCollector {
      onStreamFinished: vpn.applyStatus(text)
    }
    onExited: if (statusProc.exitCode !== 0 && String(statusProc.stdout.text).trim() === "") vpn.installed = false
  }

  Process {
    id: countriesProc

    command: ["nordvpn", "countries"]
    stdout: StdioCollector {
      onStreamFinished: {
        const list = VpnCore.parseCountries(text);
        if (list.length > 0) vpn.countries = list;
      }
    }
  }

  Process {
    id: settingsProc

    command: ["nordvpn", "settings"]
    stdout: StdioCollector {
      onStreamFinished: {
        const next = VpnCore.parseSettings(text);
        if (next.protocol !== "" || next.killSwitch || next.autoConnect) vpn.options = next;
      }
    }
  }

  Process {
    id: actionProc

    // O daemon leva um instante para refletir o novo estado.
    onExited: settle.restart()
  }

  Process {
    id: pingProc

    command: ["ping", "-n", "-c", "1", "-W", "1", vpn.state.serverIp]
    stdout: StdioCollector {
      onStreamFinished: {
        const ms = VpnCore.parseLatency(text);
        if (ms !== null) vpn.latency = ms;
      }
    }
  }

  // Conectado o poll encurta (as taxas são o delta entre dois polls); parado
  // basta um relógio lento só para saber se o daemon subiu.
  Timer {
    interval: vpn.panelOpen ? 2000 : (vpn.connected ? 3000 : 15000)
    repeat: true
    running: vpn.polling
    onTriggered: vpn.refresh()
  }

  Timer {
    interval: 5000
    repeat: true
    running: vpn.panelOpen && vpn.connected && vpn.state.serverIp !== ""
    onTriggered: if (!pingProc.running) pingProc.running = true
  }

  Timer {
    id: settle

    interval: 800
    onTriggered: vpn.refresh()
  }
}
