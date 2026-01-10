import { application } from "./application"
import { registerControllers } from 'stimulus-vite-helpers'

// Stimulusコントローラー登録
const controllers = import.meta.glob('./**/*_controller.js', { eager: true })
const componentControllers = import.meta.glob('../../views/components/**/*_controller.js', { eager: true })

registerControllers(application, controllers)
registerControllers(application, componentControllers)

export { application }
