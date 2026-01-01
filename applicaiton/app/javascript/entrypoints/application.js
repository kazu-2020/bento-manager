// Turbo のインポート（自動起動）
import '@hotwired/turbo-rails'

// Stimulus のセットアップ
import { Application } from '@hotwired/stimulus'

const application = Application.start()
application.debug = false
window.Stimulus = application

// Vite の import.meta.glob で Stimulus コントローラーを自動読み込み
const controllers = import.meta.glob('../controllers/**/*_controller.js', { eager: true })

console.log("hello world")
console.log('Found controllers:', Object.keys(controllers))

for (const path in controllers) {
  const module = controllers[path]
  const controllerName = path
    .replace(/^.*\/controllers\//, '')
    .replace(/_controller\.js$/, '')
    .replace(/_/g, '-')
    .replace(/\//g, '--')

  application.register(controllerName, module.default)
}
