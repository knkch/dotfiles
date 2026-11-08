// Element 用: User-Agent から "Electron/…" を消す。
// Jitsi 通話は Electron を見つけると独自の画面共有ダイアログ (Element では中身が空になる) を使うので、
// 普通の Chrome だと思わせて、Element 自身の画面選択を使わせる。~/.local/bin/element-desktop から読み込む。
const fix = () => {
  const { app } = require('electron');
  app.userAgentFallback = app.userAgentFallback.replace(/ Electron\/\S+/, '');
};
process.nextTick(() => { try { fix(); } catch (e) { setImmediate(fix); } });
