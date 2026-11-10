// Bandeja do sistema (specs/16-widgets.md "Bandeja"): medidas do modo `tray` e
// saneamento do que a bandeja entrega. `title`, `tooltipTitle` e `icon` vêm de
// um processo de terceiros: texto é tratado como texto puro e ícone só pode ser
// o `image://` que o Quickshell monta a partir do pixmap do item — nem
// `http://`, nem `file://`, nem `qrc:` (um app não escolhe o que a ilha lê).
export const TRAY_PANEL_WIDTH = 440;
export const TRAY_ROW_HEIGHT = 30;
export const TRAY_SEPARATOR_HEIGHT = 11;
export const TRAY_HEADER_HEIGHT = 44;
export const TRAY_HEADER_GAP = 6;
export const TRAY_PADDING = 12;
// Oito linhas cabem sem rolar; o painel cresce até aqui e o resto rola.
export const TRAY_MAX_LIST_HEIGHT = 240;
const TEXT_MAX = 64;
const ICON_MAX = 1024;
// Tira controles e colapsa espaço: o texto vai para uma `IslandText` em
// `Text.PlainText`, então o risco é só a linha quebrar o layout.
export function safeText(value, max = TEXT_MAX) {
    if (typeof value !== 'string')
        return '';
    const text = value.replace(/[\u0000-\u001f\u007f]+/g, ' ').replace(/\s+/g, ' ').trim();
    return text.length > max ? text.slice(0, max).trim() : text;
}
/** Nome do app no cabeçalho: título, dica, ou o último trecho do id. */
export function appTitle(item) {
    if (!item)
        return '';
    const title = safeText(item.title) || safeText(item.tooltipTitle);
    if (title !== '')
        return title;
    const id = safeText(item.id);
    const slash = id.lastIndexOf('/');
    return slash === -1 ? id : safeText(id.slice(slash + 1));
}
/**
 * Só o `image://` que o Quickshell resolve (pixmap ou nome de tema já
 * procurado): qualquer outro esquema fica vazio e o widget cai no glifo.
 */
export function iconSource(value) {
    if (typeof value !== 'string')
        return '';
    const source = value.trim();
    if (source.length === 0 || source.length > ICON_MAX)
        return '';
    return source.startsWith('image://') ? source : '';
}
/** Ícone `-symbolic` traz preenchimento fixo: é tingido com a cor do texto. */
export function isSymbolic(source) {
    if (typeof source !== 'string')
        return false;
    return source.split('?')[0].endsWith('-symbolic');
}
/**
 * Linhas do menu de um item. O primeiro item do menu de muitos apps repete o
 * nome do app com submenu e vem seguido de um divisor: isso já é o cabeçalho
 * do painel, então sai; divisores nas pontas também.
 */
export function menuRows(values, title = '') {
    const rows = [];
    for (const entry of values || []) {
        if (!entry)
            continue;
        rows.push({
            entry,
            separator: entry.isSeparator === true,
            text: safeText(entry.text, 60),
            enabled: entry.enabled !== false,
            hasChildren: entry.hasChildren === true,
            checked: entry.checkState === 2,
            // `QsMenuButtonType.None` = 0: os demais são botão de marcar.
            checkable: (entry.buttonType || 0) > 0,
            icon: iconSource(entry.icon),
        });
    }
    const name = safeText(title).toLowerCase();
    if (rows.length > 0 && !rows[0].separator && rows[0].hasChildren && name !== '' && rows[0].text.toLowerCase() === name)
        rows.shift();
    while (rows.length > 0 && rows[0].separator)
        rows.shift();
    while (rows.length > 0 && rows[rows.length - 1].separator)
        rows.pop();
    return rows;
}
export function rowHeight(row) {
    return row && row.separator ? TRAY_SEPARATOR_HEIGHT : TRAY_ROW_HEIGHT;
}
export function listHeight(rows) {
    if (!rows || rows.length === 0)
        return TRAY_ROW_HEIGHT;
    let height = 0;
    for (const row of rows) {
        height += rowHeight(row);
        if (height >= TRAY_MAX_LIST_HEIGHT)
            return TRAY_MAX_LIST_HEIGHT;
    }
    return height;
}
/** Altura do painel: padding 12 · cabeçalho 44 · gap 6 · lista. */
export function panelHeight(rows) {
    return TRAY_PADDING * 2 + TRAY_HEADER_HEIGHT + TRAY_HEADER_GAP + listHeight(rows);
}
