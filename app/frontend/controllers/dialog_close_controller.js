import { Controller } from "@hotwired/stimulus"

// ダイアログの中に置いたボタンに付け、囲っている <dialog> を閉じる。
// formmethod="dialog" の送信ボタンでも閉じられるが、それだとフォーム内で
// tree order 上最初の送信ボタン = default button になり、Enter キーでの
// 暗黙送信が「保存」ではなく「閉じる」に化けてしまう。
export default class extends Controller {
  close() {
    this.element.closest("dialog")?.close()
  }
}
