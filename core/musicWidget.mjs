// Opções de exibição do widget de música (specs/16-widgets.md, island-omarchy).
//
// Modos inspirados nos padrões consolidados de status bars (Waybar MPRIS, AGS, Eww):
// - 'compact': Apenas título (+ ondas de áudio e status play/pause)
// - 'full': Título e artista (+ ondas de áudio e status play/pause)
// - 'minimal': Apenas ícone/capa (+ ondas de áudio e status, sem texto)
// - 'controls': Título com botões de controle de mídia inline (anterior, play/pause, próximo)

export const MUSIC_MODES = ['compact', 'full', 'minimal', 'controls'];

export const MUSIC_MODE_LABELS = {
  compact: 'Compact',
  full: 'Full',
  minimal: 'Minimal',
  controls: 'Controls'
};

export const MUSIC_FLAGS = ['musicShowArt', 'musicShowWaves', 'musicHideIdle'];

/** Limita número inteiro dentro da faixa especificada. */
export function clampNumber(value, min, max, fallback) {
  const number = Number(value);
  if (!Number.isFinite(number)) return fallback;
  return Math.min(max, Math.max(min, Math.round(number)));
}
