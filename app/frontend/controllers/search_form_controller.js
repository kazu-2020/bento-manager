import { Controller } from "@hotwired/stimulus"

const DEBOUNCE_MS = 300

// Connects to data-controller="search-form"
export default class extends Controller {
  static targets = ["input"]

  disconnect() {
    clearTimeout(this._timer)
  }

  search() {
    clearTimeout(this._timer)
    this._timer = setTimeout(() => this.#submitSearch(), DEBOUNCE_MS)
  }

  #submitSearch() {
    const ghostForm = document.getElementById("ghost-form")
    const queryField = ghostForm?.querySelector('[name="search_query"]')
    if (!queryField) return

    queryField.value = this.inputTarget.value

    // イベントを dispatch して ghost-form コントローラーに同期・送信を依頼
    this.dispatch("searchSubmit", { bubbles: true })
  }
}
