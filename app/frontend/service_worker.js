// PWA のサービスワーカー登録。
// CSP で nonce なしのインラインスクリプトを禁じているため、head に直書きせずバンドルから登録する。
if ("serviceWorker" in navigator) {
  navigator.serviceWorker.register("/service-worker.js")
}
