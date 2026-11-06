// Opções do widget de workspaces (specs/16-widgets.md), na mesma linguagem do
// `advanced-workspaces` (MIT): um modo de exibição, um teto de ícones por
// pílula e alguns ajustes de desenho. O `Service.qml` grava cada um deles em
// `settings.json` por funções tipadas — nenhuma chave nem nenhum valor vem
// direto do chamador, como na aparência (specs/19).
//
// As chaves no arquivo continuam `ws*` (wsShowEmpty, wsMaxIcons…), iguais às
// que o widget lê.

/** Modos de exibição: `used` só as áreas de trabalho usadas, `all` todos os números da faixa. */
export const MODE_IDS = ['used', 'all'];
export const MODE_NAMES = { used: 'Only used', all: 'All numbers' };
/** Modo de um `wsShowEmpty` guardado. */
export function modeOf(showEmpty) {
    return showEmpty ? 'all' : 'used';
}
/** `wsShowEmpty` de um modo escolhido na interface. */
export function showEmptyFor(mode) {
    return mode === 'all';
}
/** Teto de ícones por pílula; 0 é sem teto (o que sobra vira `+N`). */
export const ICON_LIMITS = [0, 1, 2, 3, 4];
export function iconLimitLabel(limit) {
    return Number(limit) === 0 ? 'No limit' : String(limit);
}
/** Bandeiras do widget que a aba Aparência pode alternar. */
export const FLAGS = ['wsPerMonitor', 'wsShowIcons', 'wsLocalNumbers', 'wsScratchpad'];
/** Número inteiro dentro da faixa; fora dela ou não numérico, o padrão. */
export function clampNumber(value, min, max, fallback) {
    const number = Number(value);
    if (!Number.isFinite(number))
        return fallback;
    return Math.min(max, Math.max(min, Math.round(number)));
}
