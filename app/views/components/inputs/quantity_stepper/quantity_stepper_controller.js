import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input"]

  increment() {
    const input = this.inputTarget
    const current = parseInt(input.value, 10) || 0
    const max = parseInt(input.max, 10) || Infinity
    const step = parseInt(input.step, 10) || 1
    if (current + step <= max) {
      input.value = current + step
      this.#dispatchChange()
    }
  }

  decrement() {
    const input = this.inputTarget
    const current = parseInt(input.value, 10) || 0
    const min = parseInt(input.min, 10) || 0
    const step = parseInt(input.step, 10) || 1
    if (current - step >= min) {
      input.value = current - step
      this.#dispatchChange()
    }
  }

  #dispatchChange() {
    this.inputTarget.dispatchEvent(new Event("change", { bubbles: true }))
  }
}
