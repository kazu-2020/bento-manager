import { Controller } from "@hotwired/stimulus"

// ダイアログの中に置いたボタンに付け、囲っている <dialog> を閉じる
export default class extends Controller {
  close() {
    this.element.closest("dialog")?.close()
  }
}
