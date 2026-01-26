import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="ghost-form"
export default class extends Controller {
  static targets = ["originalForm", "ghostForm"]

  submit() {
    const formData = new FormData(this.originalFormTarget)
    formData.delete("_method")
    formData.delete("authenticity_token")

    for (const [key, value] of formData.entries()) {
      const ghostKey = "ghost_" + key
      const input = this.ghostFormTarget.querySelector(`input[name="${ghostKey}"]`)
      if (input) {
        input.value = value
      }
    }

    this.ghostFormTarget.requestSubmit()
  }
}
