// Condição do Open-Meteo → glifo Phosphor `ph-fill` (specs/07-clima.md
// "Condição → ícone"). A entrada é o código WMO de `current.weather_code` e o
// `is_day`; a tabela de códigos é a da documentação do Open-Meteo. O terceiro
// item é o rótulo em inglês: quem mostra traduz com `I18n.tr`.
const CONDITIONS = [
    [[0], ['sun-fill', 'moon-fill'], 'Clear'],
    [
        [1, 2],
        ['cloud-sun-fill', 'cloud-moon-fill'],
        'Partly cloudy',
    ],
    [[3], ['cloud-fill', 'cloud-fill'], 'Overcast'],
    [
        [45, 48],
        ['cloud-fog-fill', 'cloud-fog-fill'],
        'Fog',
    ],
    // Garoa (51–57), chuva (61–67) e pancadas (80–82).
    [
        [51, 53, 55, 56, 57, 61, 63, 65, 66, 67, 80, 81, 82],
        ['cloud-rain-fill', 'cloud-rain-fill'],
        'Rain',
    ],
    // Neve (71–77) e pancadas de neve (85–86); granizo só vem com trovoada.
    [
        [71, 73, 75, 77, 85, 86],
        ['snowflake-fill', 'snowflake-fill'],
        'Snow',
    ],
    [
        [95, 96, 99],
        ['cloud-lightning-fill', 'cloud-lightning-fill'],
        'Thunderstorm',
    ],
];
function condition(code) {
    return CONDITIONS.find(([codes]) => codes.includes(code)) || null;
}
/** Código desconhecido → `null` (quem chama decide o que mostrar no lugar). */
export function weatherGlyph(code, isDay) {
    const match = condition(code);
    if (!match)
        return null;
    return isDay ? match[1][0] : match[1][1];
}
/** Rótulo da condição em inglês; código desconhecido → `''`. */
export function weatherLabel(code) {
    const match = condition(code);
    return match ? match[2] : '';
}
