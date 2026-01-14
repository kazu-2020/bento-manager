import * as Turbo from '@hotwired/turbo';

const DEFAULT_DURATION_MS = 5000;
const ANIMATION_TIMEOUT_MS = 400;

let toastIdCounter = 0;

function dismissToast(wrapper) {
  const alert = wrapper.querySelector('.alert');

  if (!alert) {
    wrapper.remove();
    return;
  }

  alert.classList.add('animate-toast-out');
  alert.addEventListener('animationend', () => wrapper.remove(), { once: true });

  setTimeout(() => wrapper.remove(), ANIMATION_TIMEOUT_MS);
}

function createToastWrapper(templateContent) {
  const wrapper = document.createElement('div');
  wrapper.id = `toast-${++toastIdCounter}`;
  wrapper.className = 'toast-item';
  wrapper.appendChild(templateContent.cloneNode(true));
  return wrapper;
}

Turbo.StreamActions.show_toast = function () {
  const container = document.querySelector('#toast-container');

  if (!container) {
    console.warn('[show_toast] Toast container not found');
    return;
  }

  const duration = parseInt(this.getAttribute('duration') || DEFAULT_DURATION_MS, 10);
  const wrapper = createToastWrapper(this.templateContent);

  wrapper.querySelector('.alert')?.classList.add('animate-toast-in');
  wrapper.querySelector('.toast-dismiss')?.addEventListener('click', () => dismissToast(wrapper));

  container.appendChild(wrapper);

  if (duration > 0) {
    setTimeout(() => dismissToast(wrapper), duration);
  }
};
