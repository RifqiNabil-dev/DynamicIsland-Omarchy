// Formatação de hora/dia do modo compacto (specs/03-ilha.md, "Modo compacto").
// Jam mengikuti bahasa (specs/13-preferencias.md "Idioma"): 12 jam untuk
// Inggris, 24 jam untuk Indonesia.
import { tr, weekdayShort } from './i18n.mjs';
const pad = (n) => String(n).padStart(2, '0');
const hour12 = (date) => date.getHours() % 12 || 12;
const period = (date) => (date.getHours() < 12 ? 'AM' : 'PM');
/** `9:41 PM` dalam bahasa Inggris (tengah malam `12:00 AM`), `21:41` dalam
 * bahasa Indonesia. */
export function formatClock(date, lang) {
    const mm = pad(date.getMinutes());
    if (lang === 'id')
        return `${pad(date.getHours())}:${mm}`;
    return `${hour12(date)}:${mm} ${period(date)}`;
}
/** `9`, `9:30`: hora de 12h sem os minutos na hora cheia. */
function shortClock12(date) {
    const minutes = date.getMinutes();
    return minutes === 0 ? `${hour12(date)}` : `${hour12(date)}:${pad(minutes)}`;
}
/**
 * Intervalo de um evento. Em inglês, como no Google Calendar en-US, o AM/PM
 * aparece uma vez quando é o mesmo e a hora cheia não leva `:00`
 * (`9 – 10:30 AM`, `11 AM – 12:30 PM`): na coluna estreita da ilha, o
 * `9:00 AM – 10:00 AM` terpotong. Dalam bahasa Indonesia, `09:00 – 10:30`.
 */
export function formatClockRange(start, end, lang) {
    if (lang === 'id')
        return `${formatClock(start, lang)} – ${formatClock(end, lang)}`;
    const tail = `${shortClock12(end)} ${period(end)}`;
    if (period(start) === period(end))
        return `${shortClock12(start)} – ${tail}`;
    return `${shortClock12(start)} ${period(start)} – ${tail}`;
}
/** `Fri 25` dalam bahasa Inggris, `Jum 25` dalam bahasa Indonesia. */
export function formatDay(date, lang) {
    return tr(lang, '{weekday} {day}', {
        weekday: weekdayShort(lang, date.getDay()),
        day: date.getDate(),
    });
}
