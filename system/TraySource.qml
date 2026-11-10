pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.SystemTray

// Bandeja do sistema (specs/16-widgets.md "Bandeja"). Quem faz o papel de host
// é a própria ilha: com `SystemTray.items` em uso, o Quickshell registra
// `org.kde.StatusNotifierWatcher` no barramento e os apps com ícone (Vesktop,
// Telegram, Steam) passam a publicar o item — sem extensão de AppIndicator.
//
// `title`, `tooltipTitle` e `icon` vêm de um processo de terceiros; nada aqui é
// usado como caminho, URL ou marcação (ver core/tray.mjs).
Scope {
  id: tray

  // `Passive` é o app que pediu para não aparecer. A lista é recalculada
  // quando o modelo muda (app abriu, fechou, trocou de status).
  readonly property var items: {
    const model = SystemTray.items;
    if (!model)
      return [];
    const all = model.values;
    const result = [];
    for (let i = 0; i < all.length; i++) {
      const item = all[i];
      if (item && item.status !== Status.Passive)
        result.push(item);
    }
    return result;
  }
  readonly property int count: items.length
  readonly property bool hasAttention: {
    for (let i = 0; i < items.length; i++) {
      if (items[i].status === Status.NeedsAttention)
        return true;
    }
    return false;
  }

  // `SystemTray.items` só é lido quando alguém pede a lista, e é essa leitura
  // que faz o Quickshell assumir `org.kde.StatusNotifierWatcher` no barramento.
  // Sem isso o host só existiria com um widget na barra — e o app aberto antes
  // não teria onde registrar o ícone.
  Component.onCompleted: items.length

  // Clique esquerdo: mostrar/esconder a janela do app.
  function activate(item) {
    if (item)
      item.activate();
  }

  // Clique do meio: `SecondaryActivate` (o que o app definir, quase sempre abrir).
  function secondary(item) {
    if (item)
      item.secondaryActivate();
  }
}
