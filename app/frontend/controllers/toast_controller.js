import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { duration: { type: Number, default: 5000 } }

  connect() {
    this.element.classList.add('animate-toast-in')

    if (this.durationValue > 0) {
      this.timeout = setTimeout(() => this.dismiss(), this.durationValue)
    }
  }

  disconnect() {
    if (this.timeout) clearTimeout(this.timeout)
  }

  dismiss() {
    this.element.classList.add('animate-toast-out')
    this.element.addEventListener('animationend', () => this.#remove(), { once: true })
    setTimeout(() => this.#remove(), 400) // fallback
  }

  #remove() {
    // toast-item wrapper があれば削除、なければ自身を削除
    const wrapper = this.element.closest('.toast-item')
    ;(wrapper || this.element).remove()
  }
}
