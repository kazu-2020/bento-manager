import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="pos-cart"
export default class extends Controller {
  quantityChanged() {
    this.#debouncedSubmitGhostForm()
  }

  couponChanged() {
    this.#debouncedSubmitGhostForm()
  }

  #debouncedSubmitGhostForm() {
    clearTimeout(this._debounceTimer)
    this._debounceTimer = setTimeout(() => {
      this.dispatch("cartChanged", { bubbles: true })
    }, 300)
  }
}
