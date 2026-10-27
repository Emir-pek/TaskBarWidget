// Renderer ile ana surec arasindaki dar kopru.
// contextIsolation acik; renderer'a Node verilmiyor.
const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('kedi', {
  setIgnore: (v) => ipcRenderer.send('kedi:set-ignore', !!v),
  menu: () => ipcRenderer.send('kedi:menu'),
  ready: () => ipcRenderer.send('kedi:ready'),
  visible: (v) => ipcRenderer.send('kedi:visible', !!v),
  on: (channel, fn) => {
    const ok = ['scale', 'paused', 'scene', 'bounds', 'cursor'];
    if (ok.includes(channel)) ipcRenderer.on('kedi:' + channel, (_e, ...a) => fn(...a));
  },
});
