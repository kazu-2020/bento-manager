import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

export default class extends Controller {
  static targets = ["card", "hiddenInput"]
  static values = {
    formFieldsUrl: String
  }

  select(event) {
    const card = event.currentTarget
    const category = card.dataset.category

    // Update visual state
    this.cardTargets.forEach(c => {
      c.classList.remove("border-primary", "bg-primary/10")
      c.classList.add("border-base-300", "bg-base-100")
    })
    card.classList.remove("border-base-300", "bg-base-100")
    card.classList.add("border-primary", "bg-primary/10")

    // Update hidden input if available
    if (this.hasHiddenInputTarget) {
      this.hiddenInputTarget.value = category
    }

    // Load form fields via Turbo
    this.loadFormFields(category)
  }

  async loadFormFields(category) {
    const url = new URL(this.formFieldsUrlValue, window.location.origin)
    url.searchParams.set("category", category)

    const response = await fetch(url, {
      headers: {
        "Accept": "text/vnd.turbo-stream.html",
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content
      }
    })

    if (response.ok) {
      const html = await response.text()
      Turbo.renderStreamMessage(html)
    }
  }
}
