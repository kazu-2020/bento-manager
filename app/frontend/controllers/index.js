import { application } from "./application"
import { registerControllers } from 'stimulus-vite-helpers'

const controllers = import.meta.glob('../controllers/**/*_controller.js', { eager: true })
registerControllers(application, controllers)

export { application }
