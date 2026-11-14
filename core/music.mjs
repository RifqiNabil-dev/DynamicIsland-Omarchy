// Player atual, troca de faixa e formatação da música (specs/05-musica.md;
// design/logic.js `track`/`posLabel`/`posPct`).
function trackKey(player) {
    return `${player.trackId}\n${player.title}`;
}
// Parado ou sem título não tem o que mostrar: o Brave fica no barramento em
// `Stopped` com metadados vazios quando o vídeo acaba.
function showable(player) {
    return player.status !== 'Stopped' && player.title !== '';
}
/**
 * Player atual: o último que entrou em `Playing`; pausado continua atual até
 * outro tocar ou ele sair do barramento. Na primeira leitura (o `enable()`
 * roda a cada desbloqueio), os que já tocam ficam na frente dos pausados, e
 * nada dispara.
 */
export class PlayerTracker {
    constructor() {
        // Do menos para o mais recente a entrar em `Playing`.
        this.order = [];
        this.previous = new Map();
        // Última faixa vista tocando, por player. O Spotify web troca de faixa
        // pausado e só depois volta a tocar: comparar com o estado anterior
        // confundiria isso com retomar a mesma faixa.
        this.playedKeys = new Map();
        this.started = false;
    }
    update(players) {
        var _a, _b;
        const firstRead = !this.started;
        this.started = true;
        if (firstRead) {
            const withStatus = (status) => [...players].filter(([, player]) => player.status === status).map(([name]) => name);
            this.order = [...withStatus('Paused'), ...withStatus('Playing')];
        }
        else {
            this.order = this.order.filter((name) => players.has(name));
            for (const [name, player] of players) {
                if (player.status === 'Playing' && ((_a = this.previous.get(name)) === null || _a === void 0 ? void 0 : _a.status) !== 'Playing') {
                    this.order = this.order.filter((other) => other !== name);
                    this.order.push(name);
                }
            }
        }
        const current = (_b = [...this.order].reverse().find((name) => showable(players.get(name)))) !== null && _b !== void 0 ? _b : null;
        const player = current === null ? undefined : players.get(current);
        const trackChanged = !firstRead &&
            (player === null || player === void 0 ? void 0 : player.status) === 'Playing' &&
            this.playedKeys.get(current) !== trackKey(player);
        const playedKeys = new Map();
        for (const [name, snapshot] of players) {
            // Na primeira leitura, a faixa pausada conta como vista: retomar depois
            // do desbloqueio não dispara.
            const seen = showable(snapshot) && (firstRead || snapshot.status === 'Playing');
            const key = seen ? trackKey(snapshot) : this.playedKeys.get(name);
            if (key !== undefined)
                playedKeys.set(name, key);
        }
        this.playedKeys = playedKeys;
        this.previous = new Map(players);
        return { current, trackChanged };
    }
}
/** Artistas juntos com ", "; vazio mostra o nome do player (`Identity`). */
export function artistLine(artists, identity) {
    const line = artists
        .map((artist) => artist.trim())
        .filter((artist) => artist !== '')
        .join(', ');
    return line === '' ? identity : line;
}
/** `m:ss`, a partir de microssegundos (unidade do MPRIS). */
export function formatTrackTime(microseconds) {
    const total = Math.max(0, Math.floor(microseconds / 1000000));
    const minutes = Math.floor(total / 60);
    const seconds = String(total % 60).padStart(2, '0');
    return `${minutes}:${seconds}`;
}
export function progressFraction(positionUs, lengthUs) {
    if (lengthUs <= 0)
        return 0;
    return Math.max(0, Math.min(1, positionUs / lengthUs));
}
// `Position` não gera sinal: avança localmente a partir da última leitura.
export function positionAt(anchor, nowMs, lengthUs) {
    const elapsedUs = anchor.playing ? Math.max(0, nowMs - anchor.atMs) * 1000 : 0;
    const position = anchor.positionUs + elapsedUs;
    return lengthUs > 0 ? Math.min(position, lengthUs) : position;
}
// Pelo `Identity`: o Chrome se chama "Chrome" no MPRIS (e "Google Chrome" nas
// notificações), e o Firefox "Mozilla firefox". O Phosphor não tem logo do
// Firefox, então ele fica com a nota, como o Brave.
const SOURCE_GLYPHS = {
    spotify: 'spotify-logo-fill',
    chrome: 'google-chrome-logo-fill',
    'google chrome': 'google-chrome-logo-fill',
    chromium: 'google-chrome-logo-fill',
};
export const MUSIC_NOTE_GLYPH = 'music-note-fill';
export function sourceGlyph(identity) {
    var _a;
    return (_a = SOURCE_GLYPHS[identity.trim().toLowerCase()]) !== null && _a !== void 0 ? _a : MUSIC_NOTE_GLYPH;
}
// `mpris:artUrl` é escrito por qualquer app no barramento de sessão, e a
// `Image` da capa busca o que ele mandar: `file://`/`data:` (player local) e
// `http(s)` público seguem iguais, mas `http(s)` para a própria máquina ou a
// rede local é recusado (senão o player escolhe para onde o shell faz request).
// O host é normalizado antes da comparação: `http://2130706433`,
// `http://0x7f000001` e `[0:0:0:0:0:ffff:7f00:1]` são o mesmo 127.0.0.1 e
// passavam pela denylist textual antiga.
function ipv4Bytes(text) {
    if (/^\d+$/.test(text)) {
        const value = Number(text);
        if (!Number.isSafeInteger(value) || value > 0xffffffff)
            return null;
        return [(value >>> 24) & 255, (value >>> 16) & 255, (value >>> 8) & 255, value & 255];
    }
    if (/^0x[0-9a-f]+$/i.test(text)) {
        const value = parseInt(text, 16);
        if (!Number.isInteger(value) || value < 0 || value > 0xffffffff)
            return null;
        return [(value >>> 24) & 255, (value >>> 16) & 255, (value >>> 8) & 255, value & 255];
    }
    if (/^(?:0\d+|\d+)(?:\.(?:0\d+|\d+)){3}$/.test(text)) {
        const parts = text.split('.').map((part) => parseInt(part, /^0\d/.test(part) ? 8 : 10));
        return parts.every((n) => Number.isInteger(n) && n >= 0 && n <= 255) ? parts : null;
    }
    return null;
}
function isPrivateV4(bytes) {
    const [a, b] = bytes;
    return a === 0 || a === 10 || a === 127 ||
        (a === 169 && b === 254) ||
        (a === 192 && b === 168) ||
        (a === 172 && b >= 16 && b <= 31);
}
function isPrivateV6(literal) {
    const body = literal.replace(/^\[|\]$/g, '').toLowerCase();
    // IPv4 mapeado (`::ffff:127.0.0.1`, `::ffff:7f00:1`, `::127.0.0.1`).
    const mapped = /(?:^|:)(?:ffff:)?(?:(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3}))$/.exec(body);
    if (mapped)
        return isPrivateV4(mapped.slice(1).map(Number));
    const hex = /(?:^|:)ffff:([0-9a-f]{1,4}):([0-9a-f]{1,4})$/.exec(body);
    if (hex)
        return isPrivateV4([parseInt(hex[1], 16) >> 8, parseInt(hex[1], 16) & 255, parseInt(hex[2], 16) >> 8, parseInt(hex[2], 16) & 255]);
    return body === '::1' || body === '::' || /^(?:fe80|fec0|fc|fd)/.test(body);
}
/** `file:` só dentro da pasta do usuário: nada de /tmp ou de outra conta. */
function isHomeFileUrl(raw, home) {
    if (home === '')
        return false;
    const path = raw.replace(/^file:\/\//i, '').replace(/^localhost\//i, '/');
    if (!path.startsWith('/'))
        return false;
    const prefix = home.endsWith('/') ? home : home + '/';
    const decoded = (() => {
        try {
            return decodeURIComponent(path);
        }
        catch (_a) {
            return '';
        }
    })();
    if (decoded === '')
        return false;
    // `..` resolvido pelo sistema de arquivos: compara o caminho já normalizado.
    const parts = [];
    for (const part of decoded.split('/')) {
        if (part === '..')
            parts.pop();
        else if (part !== '' && part !== '.')
            parts.push(part);
    }
    return ('/' + parts.join('/')).startsWith(prefix);
}
/** URL de capa que a ilha aceita; fora disso devolve `''` (o bloco com a nota fica). */
export function safeArtUrl(url, home = '') {
    const raw = String(url || '').trim();
    if (raw === '' || !/^[a-z][a-z0-9+.-]*:/i.test(raw))
        return raw;
    if (/^file:/i.test(raw))
        return isHomeFileUrl(raw, String(home || '')) ? raw : '';
    if (!/^https?:\/\//i.test(raw))
        return raw;
    const match = /^https?:\/\/([^/?#]*)/i.exec(raw);
    let host = match ? match[1] : '';
    const at = host.lastIndexOf('@');
    if (at >= 0)
        host = host.slice(at + 1);
    const name = (host.startsWith('[') ? host.slice(0, host.indexOf(']') + 1) : host.split(':')[0]).toLowerCase();
    if (name === '' || name === 'localhost' || /\.(?:local|internal|lan|home)$/.test(name))
        return '';
    if (name.startsWith('[')) {
        if (isPrivateV6(name))
            return '';
    }
    else {
        const bytes = ipv4Bytes(name);
        if (bytes && isPrivateV4(bytes))
            return '';
    }
    return raw;
}
