// Ícone de reserva por classe de janela quando nenhum logo do tema resolve.
// Os nomes são os glifos Phosphor que o `PhIcon` carrega de `icons/`
// (`<glifo>-symbolic.svg`), não nomes de fonte Nerd.

const FALLBACK = 'square';

const CLASS_GLYPHS = [
    [/code|vscode|codium|zed|sublime|jetbrains|idea|webstorm|android-studio/, 'code-fill'],
    [/terminal|alacritty|kitty|foot|wezterm|ghostty|konsole|xterm|tmux/, 'code'],
    [/firefox|chrome|chromium|brave|vivaldi|edge|zen|browser|epiphany/, 'browser'],
    [/discord|slack|telegram|whatsapp|signal|element|mattermost|thunderbird|mail/, 'envelope-simple-fill'],
    [/spotify|music|audacious|rhythmbox|mpv|vlc|celluloid/, 'music-note-fill'],
    [/nautilus|dolphin|thunar|nemo|files|filemanager/, 'book-open'],
    [/gimp|inkscape|krita|figma|blender|obsidian/, 'palette-fill'],
    [/steam|game|lutris|heroic/, 'game-controller-fill'],
    [/libreoffice|soffice|writer|calc|impress|onlyoffice/, 'note-fill'],
    [/zoom|meet|teams|skype|jitsi/, 'device-mobile-fill'],
    [/docker|podman|virt-manager|qemu|virtualbox/, 'cpu'],
    [/code-oss|github|gitkraken|git/, 'github-logo-fill'],
];

/** Glifo Phosphor para uma classe de janela (já em minúsculas ou não). */
export function glyphFor(cls) {
    const name = String(cls || '').toLowerCase();
    if (name === '') return FALLBACK;
    for (const [pattern, glyph] of CLASS_GLYPHS) {
        if (pattern.test(name)) return glyph;
    }
    return FALLBACK;
}

export { FALLBACK };
