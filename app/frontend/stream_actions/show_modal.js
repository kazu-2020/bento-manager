import * as Turbo from "@hotwired/turbo"

let currentHandler = null

function cleanupHandler(container) {
  if (currentHandler) {
    container?.removeEventListener("turbo:submit-end", currentHandler)
    currentHandler = null
  }
}

Turbo.StreamActions.show_modal = function() {
  const container = document.querySelector("turbo-stream-modal-container")
  if (!container) return

  cleanupHandler(container)

  container.replaceChildren(this.templateContent)
  const dialog = container.querySelector("dialog")

  currentHandler = (event) => {
    if (event.detail.success) {
      dialog?.close()
      cleanupHandler(container)
    }
  }
  container.addEventListener("turbo:submit-end", currentHandler)

  dialog?.showModal()
}
