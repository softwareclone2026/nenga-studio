// レンダラへ渡す API（contextBridge）。

const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('nengaApi', {
  openDocument: () => ipcRenderer.invoke('document:open'),
  saveDocument: (payload) => ipcRenderer.invoke('document:save', payload),
  importCSV: () => ipcRenderer.invoke('csv:import'),
  exportCSV: (payload) => ipcRenderer.invoke('csv:export', payload),
  decodeShiftJIS: (bytes) => ipcRenderer.invoke('csv:decodeShiftJIS', Array.from(bytes)),
  encodeShiftJIS: (text) => ipcRenderer.invoke('csv:encodeShiftJIS', text),
  importImage: () => ipcRenderer.invoke('image:import'),
  exportPdf: (payload) => ipcRenderer.invoke('pdf:export', payload),
  printPages: (payload) => ipcRenderer.invoke('print:pages', payload),
  openPath: (target) => ipcRenderer.invoke('shell:openPath', target),
  showItem: (target) => ipcRenderer.invoke('shell:showItem', target),
  message: (payload) => ipcRenderer.invoke('app:message', payload),
  onMenu: (handler) => {
    ipcRenderer.on('menu', (_event, action) => handler(action));
  },
});
