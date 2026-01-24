import * as Turbo from '@hotwired/turbo';

let toastIdCounter = 0;

Turbo.StreamActions.show_toast = function () {
  const container = document.querySelector('#toast-container');

  if (!container) {
    console.warn('[show_toast] Toast container not found');
    return;
  }

  const wrapper = document.createElement('div');
  wrapper.id = `toast-${++toastIdCounter}`;
  wrapper.className = 'toast-item';
  wrapper.appendChild(this.templateContent.cloneNode(true));

  container.appendChild(wrapper);
  // dismiss は Toast::Component の Stimulus コントローラーが処理
};
