import { application } from "./application"
import { registerControllers } from 'stimulus-vite-helpers'

// Stimulusコントローラー登録
const controllers = import.meta.glob('./**/*_controller.js', { eager: true })
registerControllers(application, controllers)

// ViewComponent内のコントローラーを手動登録
import ToastController from "../../views/components/toast/toast_controller"
application.register("toast", ToastController)

import QuantityStepperController from "../../views/components/inputs/quantity_stepper/quantity_stepper_controller"
application.register("quantity-stepper", QuantityStepperController)

export { application }
