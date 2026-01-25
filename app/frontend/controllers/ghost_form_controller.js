import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="ghost-form"
export default class extends Controller {
  static targets = [ "originalForm", "ghostForm" ]

  submit(event) {
    const formData = new FormData(this.originalFormTarget)
    formData.delete("_method")
    formData.delete("authenticity_token")

    // チェックボックス用の hidden fields をすべて "0" にリセット
    this.ghostFormTarget.querySelectorAll('input[type="hidden"]').forEach(input => {
      if (input.name.includes("[selected]")) {
        input.value = "0"
      }
    })

    // Original Form の値を Ghost Form にコピー
    for (const [key, value] of formData.entries()) {
      const ghost_key = "ghost_" + key
      const input = this.ghostFormTarget.querySelector(`input[name="${ghost_key}"]`)
      if (input) {
        input.value = value
      }
    }

    this.ghostFormTarget.requestSubmit()
  }
}
