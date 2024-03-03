import { Application } from "@hotwired/stimulus"
import Clipboard from 'stimulus-clipboard'
import { Tabs } from 'tailwindcss-stimulus-components'

const application = Application.start()
application.register('clipboard', Clipboard)
application.register('tabs', Tabs)

// Configure Stimulus development experience
application.debug = false
window.Stimulus   = application

export { application }

