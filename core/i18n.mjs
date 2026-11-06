// Bahasa antarmuka (specs/13-preferencias.md "Idioma"). Omarchy tidak memakai
// gettext: teks sumbernya bahasa Inggris, dan `ID` (i18nId.mjs) menerjemahkan
// setiap teks utuh, dengan `{name}` sebagai tempat nilai. Siapa pun yang
// menyimpan teks di tabel untuk diterjemahkan nanti menandainya dengan `msg`,
// dan uji katalog menemukan tanda itu.
import { ID } from './i18nId.mjs';
export const LANGUAGE_IDS = ['en', 'id'];
export function sanitizeLanguage(value) {
    var _a;
    return (_a = LANGUAGE_IDS.find((id) => id === value)) !== null && _a !== void 0 ? _a : 'en';
}
/** Marca um texto para o catálogo sem traduzir: a tradução vem depois, com `tr`. */
export function msg(text) {
    return text;
}
/** `{nome}` sem valor em `params` fica como está, para o erro aparecer na tela. */
export function tr(lang, text, params = {}) {
    var _a;
    const template = lang === 'id' ? ((_a = ID[text]) !== null && _a !== void 0 ? _a : text) : text;
    return template.replace(/\{(\w+)\}/g, (whole, key) => key in params ? String(params[key]) : whole);
}
/** `one` com `n` igual a 1 e `other` no resto; `{n}` vira o número. */
export function trCount(lang, n, one, other, params = {}) {
    return tr(lang, n === 1 ? one : other, Object.assign({}, params, { n }));
}
const WEEKDAYS = {
    en: ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'],
    id: ['Min', 'Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab'],
};
const MONTHS = {
    en: [
        'January',
        'February',
        'March',
        'April',
        'May',
        'June',
        'July',
        'August',
        'September',
        'October',
        'November',
        'December',
    ],
    id: [
        'Januari',
        'Februari',
        'Maret',
        'April',
        'Mei',
        'Juni',
        'Juli',
        'Agustus',
        'September',
        'Oktober',
        'November',
        'Desember',
    ],
};
/** `day` como `Date.getDay()`: 0 é domingo. */
export function weekdayShort(lang, day) {
    var _a;
    return (_a = WEEKDAYS[lang][day]) !== null && _a !== void 0 ? _a : '';
}
/** `month` como `Date.getMonth()`: 0 é janeiro. */
export function monthName(lang, month) {
    var _a;
    return (_a = MONTHS[lang][month]) !== null && _a !== void 0 ? _a : '';
}
