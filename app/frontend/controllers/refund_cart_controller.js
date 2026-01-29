import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="refund-cart"
export default class extends Controller {
  disconnect() {
    clearTimeout(this._debounceTimer)
    this._debounceTimer = null
  }

  toggle() {
    this.#debouncedSubmitGhostForm()
  }

  #debouncedSubmitGhostForm() {
    clearTimeout(this._debounceTimer)
    this._debounceTimer = setTimeout(() => {
      this.dispatch("cartChanged", { bubbles: true })
    }, 100)
  }
}
