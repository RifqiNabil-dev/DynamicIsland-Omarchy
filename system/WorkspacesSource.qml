pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import "../core/workspaceIcons.mjs" as IconCore

// Estado dos workspaces do Hyprland para o widget `workspaces` (spec 16).
// Vive no `SystemSources.qml`, uma instância para todos os monitores: a
// filtragem por monitor é do widget, que sabe em qual barra está.
//
// O Quickshell não reconsulta workspaces nem toplevels sozinho, então os
// eventos crus do Hyprland empurram `refreshWorkspaces`/`refreshToplevels` e
// incrementam `revision` — as ligações que dependem do estado releem quando
// ele muda sem virar propriedade (focusedmon, urgent).
Scope {
  id: source

  property int revision: 0
  // Os logos vêm do `DesktopEntries`, que termina de varrer os .desktop
  // alguns segundos depois de a shell subir: o que resolveu antes disso não
  // pode ser memorizado como "não existe".
  property var iconCache: ({})
  property int desktopRevision: 0

  readonly property var windowEvents: [
    "openwindow", "closewindow", "movewindow", "movewindowv2", "windowtitle",
    "windowtitlev2", "activewindow", "activewindowv2", "urgent"
  ]
  readonly property var workspaceEvents: [
    "workspace", "workspacev2", "createworkspace", "createworkspacev2",
    "destroyworkspace", "destroyworkspacev2", "moveworkspace", "moveworkspacev2",
    "focusedmon", "configreloaded"
  ]
  readonly property var specialEvents: ["activespecial", "activespecialv2"]

  Connections {
    target: Hyprland

    function onRawEvent(event) {
      const name = event.name;
      if (source.windowEvents.indexOf(name) !== -1) {
        Hyprland.refreshToplevels();
        source.revision++;
      } else if (source.workspaceEvents.indexOf(name) !== -1) {
        Hyprland.refreshWorkspaces();
        source.revision++;
      } else if (source.specialEvents.indexOf(name) !== -1) {
        Hyprland.refreshWorkspaces();
        Hyprland.refreshMonitors();
        source.revision++;
      }
    }
  }

  Connections {
    target: DesktopEntries

    function onApplicationsChanged() {
      source.iconCache = ({});
      source.desktopRevision++;
    }
  }

  // `Hyprland.workspaces.values` só lista os workspaces que existem agora;
  // `showEmpty` sintetiza os que faltam a partir de `maxWorkspaceId`.
  readonly property var workspaces: {
    const _ = source.revision;
    return Hyprland.workspaces.values;
  }

  readonly property var monitors: {
    const _ = source.revision;
    return Hyprland.monitors.values;
  }

  function workspaceById(id) {
    const values = source.workspaces;
    for (let i = 0; i < values.length; i++) {
      if (values[i].id === id) return values[i];
    }
    return null;
  }

  function workspaceByName(name) {
    const values = source.workspaces;
    for (let i = 0; i < values.length; i++) {
      if (String(values[i].name || "") === name) return values[i];
    }
    return null;
  }

  function hasWindows(workspace) {
    if (!workspace) return false;
    const tops = workspace.toplevels ? workspace.toplevels.values : null;
    return !!tops && tops.length > 0;
  }

  /** Monitor dono do workspace: objeto no workspace, texto no IPC cru. */
  function monitorName(workspace) {
    if (!workspace) return "";
    if (workspace.monitor && workspace.monitor.name) return String(workspace.monitor.name);
    const ipc = workspace.lastIpcObject;
    if (ipc && ipc.monitor) return String(ipc.monitor);
    return "";
  }

  function monitorIndex(screenName) {
    const values = source.monitors;
    for (let i = 0; i < values.length; i++) {
      if (String(values[i].name) === screenName) return i;
    }
    return -1;
  }

  /** Workspace ativo neste monitor (não é o focado global com dois monitores). */
  function activeIdFor(screenName) {
    const _ = source.revision;
    const values = source.monitors;
    for (let i = 0; i < values.length; i++) {
      if (String(values[i].name) !== screenName) continue;
      if (values[i].activeWorkspace) return values[i].activeWorkspace.id;
      break;
    }
    return Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : -1;
  }

  function isFocusedMonitor(screenName) {
    const _ = source.revision;
    if (screenName === "" || !Hyprland.focusedMonitor) return true;
    return String(Hyprland.focusedMonitor.name) === screenName;
  }

  function windowClass(toplevel) {
    const ipc = toplevel ? toplevel.lastIpcObject : null;
    if (ipc && ipc.class) return String(ipc.class);
    if (toplevel && toplevel.class) return String(toplevel.class);
    if (toplevel && toplevel.appId) return String(toplevel.appId);
    return "";
  }

  /** Logo do tema de ícones para a classe da janela; "" quando não resolve. */
  function iconSource(cls) {
    if (cls === "") return "";
    const cached = source.iconCache[cls];
    if (cached !== undefined) return cached;

    let resolved = "";
    try {
      const entry = DesktopEntries.byId(cls) || DesktopEntries.heuristicLookup(cls);
      const name = entry && entry.icon ? String(entry.icon) : "";
      if (name.charAt(0) === "/") resolved = "file://" + name;
      else if (name.indexOf("file://") === 0 || name.indexOf("image://") === 0) resolved = name;
      else if (name !== "") resolved = Quickshell.iconPath(name, true) || "";
    } catch (e) {
      resolved = "";
    }

    source.iconCache[cls] = resolved;
    return resolved;
  }

  /**
   * Uma entrada por janela do workspace: `{source, glyph}`. Sem logo, o glifo
   * Phosphor da classe (`fallback`). `maxIcons` > 0 corta e fecha com `+N`.
   */
  function iconsFor(workspace, maxIcons) {
    const _ = source.desktopRevision;
    if (!workspace) return [];
    const tops = workspace.toplevels ? workspace.toplevels.values : null;
    if (!tops || tops.length === 0) return [];

    const limit = maxIcons > 0 ? Math.min(tops.length, maxIcons) : tops.length;
    const entries = [];
    for (let i = 0; i < limit; i++) {
      const cls = source.windowClass(tops[i]);
      entries.push({ source: source.iconSource(cls), glyph: IconCore.glyphFor(cls) });
    }
    if (tops.length > limit) entries.push({ source: "", glyph: "+" + (tops.length - limit) });
    return entries;
  }

  /**
   * Foca/cria um workspace. Só o id numérico entra no comando; o Hyprland
   * 0.5x em diante (Omarchy Quattro) só aceita o `dispatch` na forma Lua.
   */
  function focusWorkspace(id) {
    const value = Number(id);
    if (!isFinite(value) || value <= 0 || Math.floor(value) !== value) {
      console.warn("Island: blocked workspaces focus with invalid id:", id);
      return;
    }
    Quickshell.execDetached(["hyprctl", "dispatch", 'hl.dsp.focus({ workspace = "' + value + '" })']);
  }

  /** Habilita/desabilita um workspace especial (`special:scratchpad`). */
  function toggleSpecial(name) {
    const raw = String(name || "");
    // O nome chega de `settings.json`; só `special:<slug>` é aceito para não
    // virar argumento arbitrário do hyprctl.
    const match = /^special:[A-Za-z0-9_-]{1,32}$/.exec(raw);
    if (!match) {
      console.warn("Island: blocked workspaces special name:", raw);
      return;
    }
    Quickshell.execDetached(["hyprctl", "dispatch", 'hl.dsp.workspace.toggle_special("' + match[1] + '")']);
  }

  function specialOpen(screenName, name) {
    const _ = source.revision;
    const values = source.monitors;
    for (let i = 0; i < values.length; i++) {
      if (String(values[i].name) !== screenName) continue;
      const ipc = values[i].lastIpcObject;
      const special = ipc ? ipc.specialWorkspace : null;
      return !!special && String(special.name || "") === name;
    }
    return false;
  }
}
