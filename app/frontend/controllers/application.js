import { Application } from '@hotwired/stimulus';

const application = Application.start();

// 開発用のデバッグ支援。import.meta.env.DEV はビルド時に静的置換されるため、
// 本番バンドルからはこのブロックごと削除される
if (import.meta.env.DEV) {
  application.debug = true;
  window.Stimulus = application;
}

export { application };
