// NordVPN: o CLI `nordvpn` interpretado, as taxas do `Transfer:` e o
// modelo do painel `vpn`/do widget. A UI só desenha o que sai daqui
// (specs/16-widgets.md "Widgets").
import { msg, tr } from './i18n.mjs';
import * as GeoCore from './geo.mjs';

/** Atalhos de conexão: nomes como `nordvpn countries` devolve (com `_`). */
export const QUICK_COUNTRIES = ['Indonesia', 'Japan', 'Singapore', 'United_States'];
const UNITS = { b: 1, kb: 1000, kib: 1024, mb: 1000 ** 2, mib: 1024 ** 2, gb: 1000 ** 3, gib: 1024 ** 3 };
const EMPTY_STATUS = {
    status: '',
    connected: false,
    connecting: false,
    loggedIn: true,
    hostname: '',
    country: '',
    city: '',
    serverIp: '',
    technology: '',
    protocol: '',
    server: '',
    transferIn: null,
    transferOut: null,
    uptime: '',
};
/** `Status: Connected` + `Hostname:`, `IP:`, `Country:`, `City:`… (CLI 4+/6+). */
export function parseStatus(text) {
    const state = Object.assign({}, EMPTY_STATUS);
    String(text !== null && text !== void 0 ? text : '')
        .split('\n')
        .forEach((raw) => {
        const line = raw.trim();
        if (line === '')
            return;
        if (/not logged in/i.test(line)) {
            state.loggedIn = false;
            return;
        }
        const split = line.indexOf(':');
        if (split <= 0)
            return;
        const key = line.slice(0, split).trim().toLowerCase();
        const value = line.slice(split + 1).trim();
        if (key === 'status')
            state.status = value;
        else if (key === 'hostname')
            state.hostname = value;
        else if (key === 'ip')
            state.serverIp = value;
        else if (key === 'country')
            state.country = value;
        else if (key === 'server')
            state.server = value;
        else if (key === 'city')
            state.city = value;
        else if (key === 'current technology' || key === 'technology')
            state.technology = value;
        else if (key === 'current protocol' || key === 'protocol')
            state.protocol = value;
        else if (key === 'uptime')
            state.uptime = value;
        else if (key === 'transfer') {
            const parts = value.split(',');
            state.transferIn = parseSize(parts[0]);
            state.transferOut = parseSize(parts[1]);
        }
    });
    state.connected = /^connected$/i.test(state.status);
    state.connecting = /^(connecting|reconnecting)/i.test(state.status);
    return state;
}
/** `6.46 KiB received` → bytes. */
export function parseSize(text) {
    const match = /([\d.]+)\s*(b|kb|kib|mb|mib|gb|gib)/i.exec(String(text !== null && text !== void 0 ? text : ''));
    if (!match)
        return null;
    const factor = UNITS[match[2].toLowerCase()];
    if (factor === undefined)
        return null;
    return parseFloat(match[1]) * factor;
}
/** `Kill Switch: disabled`, `Auto-connect: enabled`, `Protocol: NordLynx`. */
export function parseSettings(text) {
    const out = { killSwitch: false, autoConnect: false, protocol: '', firewall: false };
    String(text !== null && text !== void 0 ? text : '')
        .split('\n')
        .forEach((raw) => {
        const line = raw.trim();
        const split = line.indexOf(':');
        if (split <= 0)
            return;
        const key = line.slice(0, split).trim().toLowerCase();
        const value = line.slice(split + 1).trim().toLowerCase();
        if (key === 'kill switch')
            out.killSwitch = value === 'enabled';
        else if (key === 'auto-connect')
            out.autoConnect = value === 'enabled';
        else if (key === 'protocol')
            out.protocol = line.slice(split + 1).trim();
        else if (key === 'firewall')
            out.firewall = value === 'enabled';
    });
    return out;
}
/**
 * Bytes/s entre duas leituras de `Transfer:` do `nordvpn status` (o cliente
 * Linux não expõe interface de túnel no host: o NordLynx roda em namespace
 * próprio, então os contadores não estão em `/sys/class/net`).
 */
export function rates(beforeIn, beforeOut, afterIn, afterOut, seconds) {
    const span = Math.max(0.001, seconds);
    return {
        down: Math.max(0, afterIn - beforeIn) / span,
        up: Math.max(0, afterOut - beforeOut) / span,
    };
}
/** `time=246 ms` / `time<1 ms` do ping. */
export function parseLatency(text) {
    const match = /time[=<]\s*([\d.]+)\s*ms/i.exec(String(text !== null && text !== void 0 ? text : ''));
    if (!match)
        return null;
    const ms = parseFloat(match[1]);
    return Number.isFinite(ms) ? Math.round(ms) : null;
}
export function formatRate(bytesPerSecond) {
    const value = Number.isFinite(bytesPerSecond) ? Math.max(0, bytesPerSecond) : 0;
    if (value < 1)
        return '0 KB/s';
    if (value >= 1024 * 1024)
        return (value / (1024 * 1024)).toFixed(1) + ' MB/s';
    if (value >= 100 * 1024)
        return Math.round(value / 1024) + ' KB/s';
    if (value >= 1024)
        return (value / 1024).toFixed(2) + ' KB/s';
    return Math.round(value) + ' B/s';
}
/**
 * `NORDLYNX`/`UDP` → `NordLynx UDP` (o mesmo rótulo que o app mostra).
 *
 * O `nordvpn status` é irregular com esses dois campos: em versões novas vêm
 * `Current technology`/`Current protocol`, em outras só `Protocol: NordLynx` —
 * aí o valor é a tecnologia, não o transporte. Sem nada no `status`, cai no
 * `Protocol` do `nordvpn settings`, que sempre existe.
 */
const TECHNOLOGIES = { nordlynx: 'NordLynx', openvpn: 'OpenVPN', wireguard: 'NordLynx' };
const TECH_WORDS = new Set(Object.keys(TECHNOLOGIES));
const lower = (value) => String(value || '').trim().toLowerCase();
export function transportLabel(state, fallbackProtocol) {
    let tech = lower(state && state.technology);
    let protocol = lower(state && state.protocol);
    const fallback = lower(fallbackProtocol);
    if (TECH_WORDS.has(protocol)) {
        if (tech === '')
            tech = protocol;
        protocol = '';
    }
    if (tech === '' && TECH_WORDS.has(fallback))
        tech = fallback;
    if (protocol === '' && (fallback === 'udp' || fallback === 'tcp'))
        protocol = fallback;
    // NordLynx e WireGuard só andam sobre UDP.
    if (protocol === '' && (tech === 'nordlynx' || tech === 'wireguard'))
        protocol = 'udp';
    const name = TECHNOLOGIES[tech] || (tech !== '' ? tech.charAt(0).toUpperCase() + tech.slice(1) : '');
    return [name, protocol.toUpperCase()].filter((part) => part !== '').join(' ');
}
/** `Server: Japan #1181` → `#1181`; sem isso, `jp1181.nordvpn.com` → `#1181`. */
export function serverNumber(state) {
    const fromStatus = /#\s*(\d+)/.exec(String((state && state.server) || ''));
    if (fromStatus)
        return '#' + fromStatus[1];
    const fromHost = /^[a-z]{2}(\d+)\./i.exec(String((state && state.hostname) || ''));
    return fromHost ? '#' + fromHost[1] : '';
}
/** `sg674.nordvpn.com` → `SG`; sem hostname, cai no nome do país do `status`. */
export function countryCode(state) {
    const fromHost = /^([a-z]{2})\d*\./i.exec(String((state && state.hostname) || ''));
    if (fromHost)
        return fromHost[1].toUpperCase();
    return GeoCore.codeOf((state && state.country) || '');
}
/** Ponto do marcador no mapa: [lon, lat] do país do servidor, ou null. */
export function mapPoint(state) {
    return GeoCore.point(countryCode(state));
}
/** Bytes em IEC, como o próprio CLI escreve o `Transfer:`. */
export function formatBytes(bytes) {
    const value = Number.isFinite(bytes) ? Math.max(0, bytes) : 0;
    if (value < 1024)
        return Math.round(value) + ' B';
    if (value < 1024 * 1024)
        return (value / 1024).toFixed(1) + ' KiB';
    if (value < 1024 ** 3)
        return (value / 1024 ** 2).toFixed(1) + ' MiB';
    return (value / 1024 ** 3).toFixed(2) + ' GiB';
}
/** `United_States` → `United States`. */
export function countryLabel(name) {
    return String(name !== null && name !== void 0 ? name : '').replace(/_/g, ' ');
}
/** Só os países do atalho aparecem na fileira de botões. */
export function isQuickCountry(name) {
    return QUICK_COUNTRIES.includes(name);
}
/** Qualquer país da lista serve de argumento para `nordvpn connect`. */
export function isCountryToken(name) {
    return /^[A-Za-z][A-Za-z_]*$/.test(String(name !== null && name !== void 0 ? name : '').trim());
}
/** `nordvpn countries` (um nome por linha, com `_`) → tokens do CLI. */
export function parseCountries(text) {
    return String(text !== null && text !== void 0 ? text : '')
        .split(/\r?\n|,/)
        .map((line) => line.trim())
        .filter((line) => isCountryToken(line));
}
/**
 * Altura do painel: 14px de padding, cabeçalho 44, grade 2×4 de 30 por linha,
 * o cartão do mapa (faixa `CONECTADO · …` + alternador Peta/Daftar de 22, 6px
 * de respiro e o mapa com a proporção do recorte geográfico: 412px de largura
 * → 163), divisores de 21 (10 + 1 + 10), atalhos de 30, duas opções de 24 e os
 * 2px do anel.
 */
export function vpnPanelHeight() {
    // 14 + 44 + 21 + 60 + 21 + 191 + 21 + 30 + 21 + 48 + 14 + 2 = 487
    return 488;
}
function place(state) {
    const city = String(state.city || '').trim();
    const country = countryLabel(state.country).trim();
    if (city !== '' && country !== '')
        return city + ', ' + country;
    return city || country;
}
export function statusLabel(state, lang) {
    if (state.loggedIn === false)
        return tr(lang, msg('Not logged in'));
    if (state.connecting === true)
        return tr(lang, msg('Connecting…'));
    if (state.connected !== true)
        return tr(lang, msg('Disconnected'));
    const where = place(state);
    return where === '' ? tr(lang, msg('Connected')) : tr(lang, msg('Connected')) + ' · ' + where;
}
/**
 * Modelo do painel `vpn`: cabeçalho (ponto de status, país em destaque, a
 * linha `cidade · país #id · transporte`), grade 2×4, mapa com o marcador do
 * servidor, atalhos de país, opções do daemon e o botão de ação — o layout do
 * app da NordVPN, com as cores do `Tokens`.
 */
export function vpnPanel(state, view, latency, lang, settings, countries) {
    const connected = state.connected === true;
    const connecting = state.connecting === true;
    const loggedIn = state.loggedIn !== false;
    const sentinel = '—';
    const country = countryLabel(state.country).trim();
    const city = String(state.city || '').trim();
    const transport = transportLabel(state, settings ? settings.protocol : '');
    const number = serverNumber(state);
    const where = country !== '' && number !== '' ? country + ' ' + number : country;
    const live = (value) => (connected ? value : sentinel);
    // Desconectado não há país: o cabeçalho mostra o estado no lugar dele.
    const heading = connected && country !== '' ? country : connecting ? tr(lang, msg('Connecting…')) : loggedIn ? tr(lang, msg('Disconnected')) : tr(lang, msg('Not logged in'));
    return {
        online: connected,
        connecting,
        country: heading,
        // `Tóquio · Japão #1181 · NordLynx UDP`; sem conexão, o convite a escolher um.
        meta: connected
            ? [city, where, transport].filter((part) => part !== '').join(' · ')
            : connecting ? where : tr(lang, msg('Choose a country to connect')),
        status: connected ? tr(lang, msg('Connected')) : connecting ? tr(lang, msg('Connecting…')) : loggedIn ? tr(lang, msg('Disconnected')) : tr(lang, msg('Not logged in')),
        // `CONNECTED · JAPAN`: a faixa que o app desenha sobre o mapa.
        badge: [connected ? tr(lang, msg('Connected')) : connecting ? tr(lang, msg('Connecting…')) : tr(lang, msg('Disconnected')), connected ? country.toUpperCase() : '']
            .filter((part) => part !== '')
            .join(' · ')
            .toUpperCase(),
        metrics: [
            { label: tr(lang, msg('Download')), value: live(formatRate(view.down)) },
            { label: tr(lang, msg('Upload')), value: live(formatRate(view.up)) },
            { label: tr(lang, msg('Latency')), value: connected && latency >= 0 ? latency + ' ms' : sentinel },
            { label: tr(lang, msg('Server IP')), value: live(state.serverIp !== '' ? state.serverIp : sentinel) },
            { label: tr(lang, msg('Hostname')), value: live(state.hostname !== '' ? state.hostname : sentinel) },
            { label: tr(lang, msg('City')), value: live(city !== '' ? city : sentinel) },
            { label: tr(lang, msg('Protocol')), value: live(transport !== '' ? transport : sentinel) },
            {
                label: tr(lang, msg('Transfer')),
                value: live(state.transferIn === null && state.transferOut === null ? sentinel : '\u2193 ' + formatBytes(state.transferIn) + ' \u00b7 \u2191 ' + formatBytes(state.transferOut)),
            },
        ],
        map: {
            point: connected ? mapPoint(state) : null,
            code: countryCode(state),
        },
        quick: QUICK_COUNTRIES.map((quick) => ({
            id: quick,
            label: countryLabel(quick),
            active: connected && countryLabel(state.country) === countryLabel(quick),
        })),
        // A lista completa (`nordvpn countries`, ~150 países) em ordem alfabética
        // pelo rótulo já traduzido; o país da sessão fica marcado.
        countries: (Array.isArray(countries) ? countries : [])
            .map((token) => ({ id: token, label: countryLabel(token) }))
            .sort((a, b) => a.label.localeCompare(b.label, lang === '' ? 'en' : lang, { sensitivity: 'base' }))
            .map((item) => ({
            id: item.id,
            label: item.label,
            active: connected && countryLabel(state.country).toLowerCase() === item.label.toLowerCase(),
        })),
        options: [
            { id: 'killSwitch', label: tr(lang, msg('Kill switch')), on: settings ? settings.killSwitch === true : false },
            { id: 'autoConnect', label: tr(lang, msg('Auto-connect')), on: settings ? settings.autoConnect === true : false },
        ],
        action: {
            label: connected ? tr(lang, msg('Disconnect')) : connecting ? tr(lang, msg('Connecting…')) : tr(lang, msg('Connect')),
            enabled: loggedIn && !connecting,
        },
    };
}
/** Widget da barra: país quando conectado, `Off` quando não. */
export function vpnWidgetView(state, latency, lang) {
    const connected = state.connected === true;
    if (state.loggedIn === false)
        return { on: false, label: tr(lang, msg('Not logged in')), sub: '' };
    if (state.connecting === true)
        return { on: false, label: tr(lang, msg('Connecting…')), sub: '' };
    if (!connected)
        return { on: false, label: tr(lang, msg('Off')), sub: '' };
    const label = countryLabel(state.country).trim() || tr(lang, msg('Connected'));
    return {
        on: true,
        label,
        sub: latency >= 0 ? latency + ' ms' : '',
    };
}
