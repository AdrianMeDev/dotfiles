// Version pinned to the official Zebar 3 client; Zebar caches remote imports.
import { createProviderGroup } from 'https://esm.sh/zebar@3.0.0';
const providers = createProviderGroup({ glazewm: { type: 'glazewm' }, network: { type: 'network' }, battery: { type: 'battery' } });
const nav = document.querySelector('#workspaces');
const status = document.querySelector('#status');
const buttons = Array.from({ length: 9 }, (_, i) => {
  const button = document.createElement('button');
  button.textContent = String(i + 1);
  button.setAttribute('aria-label', `Workspace ${i + 1}`);
  button.addEventListener('click', async () => {
    const wm = providers.outputMap.glazewm;
    if (!wm) return;
    try {
      // The monitor subject makes an unopened workspace appear on the clicked bar's monitor.
      await wm.runCommand(`focus --workspace ${i + 1}`, wm.currentMonitor.id);
      status.textContent = '';
    } catch (error) { status.textContent = 'Workspace-Fehler'; console.error(error); }
  });
  nav.append(button);
  return button;
});
function containsWindow(container) {
  return container.type === 'window' || (container.children ?? []).some(containsWindow);
}
function render() {
  const { glazewm: wm, network, battery } = providers.outputMap;
  buttons.forEach((button, index) => {
    const workspace = wm?.allWorkspaces.find(w => w.name === String(index + 1));
    button.disabled = !wm;
    button.classList.toggle('occupied', !!workspace && containsWindow(workspace));
    button.classList.toggle('displayed', workspace?.id === wm?.displayedWorkspace?.id && !!workspace);
    button.classList.toggle('focused', !!workspace?.hasFocus);
    button.setAttribute('aria-current', workspace?.hasFocus ? 'true' : 'false');
  });
  document.querySelector('#network').textContent = network?.defaultInterface
    ? (network.defaultGateway?.ssid || network.defaultInterface.friendlyName || network.defaultInterface.type)
    : 'Offline';
  document.querySelector('#battery').textContent = Number.isFinite(battery?.chargePercent)
    ? `${battery.isCharging ? '↗ ' : ''}${Math.round(battery.chargePercent)}%` : '';
}
providers.onOutput(render);
render();
function clock() { document.querySelector('#clock').textContent = new Date().toLocaleString('de-DE', { dateStyle: 'medium', timeStyle: 'short' }); }
clock();
setInterval(clock, 1000);
