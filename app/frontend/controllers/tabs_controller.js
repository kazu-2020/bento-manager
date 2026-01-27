import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["tab", "panel"]
  static values = { index: { type: Number, default: 0 } }

  indexValueChanged() {
    this.#updateTabs()
  }

  select(event) {
    this.indexValue = this.tabTargets.indexOf(event.currentTarget)
  }

  #updateTabs() {
    this.tabTargets.forEach((tab, i) => {
      tab.classList.toggle("tab-active", i === this.indexValue)
    })
    this.panelTargets.forEach((panel, i) => {
      panel.hidden = i !== this.indexValue
    })
  }
}
