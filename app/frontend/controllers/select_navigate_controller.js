import { Controller } from "@hotwired/stimulus"
import * as Turbo from "@hotwired/turbo"

// 選択肢の value を遷移先パスとして持つ <select> に付け、選択と同時に画面を切り替える
export default class extends Controller {
  visit() {
    if (this.element.value) Turbo.visit(this.element.value)
  }
}
