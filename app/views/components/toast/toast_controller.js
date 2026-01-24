import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { duration: { type: Number, default: 5000 } }

  connect() {
    this.element.classList.add('animate-toast-in')

    if (this.durationValue > 0) {
      this.autoDismissTimeout = setTimeout(() => this.dismiss(), this.durationValue)
    }
  }

  disconnect() {
    if (this.autoDismissTimeout) clearTimeout(this.autoDismissTimeout)
  }

  dismiss() {
    clearTimeout(this.autoDismissTimeout)
    this.autoDismissTimeout = null

    this.element.classList.add('animate-toast-out')
    this.element.addEventListener('animationend', () => this.#remove(), { once: true })
    setTimeout(() => this.#remove(), 400) // fallback
  }

  #remove() {
    const wrapper = this.element.closest('.toast-item');
    const target = wrapper || this.element;
    target.remove();
  }
}
