import * as Turbo from '@hotwired/turbo';

Turbo.StreamActions.show_toast = function () {
  const container = document.querySelector('#toast-container');

  if (!container) {
    console.warn('[show_toast] Toast container not found');
    return;
  }

  const wrapper = document.createElement('div');
  wrapper.className = 'toast-item';
  wrapper.appendChild(this.templateContent.cloneNode(true));

  container.appendChild(wrapper);
};
