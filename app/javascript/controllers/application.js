import { Application } from "@hotwired/stimulus"
import Clipboard from 'stimulus-clipboard'
import CheckboxSelectAll from 'stimulus-checkbox-select-all'
import { Tabs, Slideover, Dropdown } from 'tailwindcss-stimulus-components'

const application = Application.start()
application.register('clipboard', Clipboard)
application.register('tabs', Tabs)
application.register('slideover', Slideover)
application.register('dropdown', Dropdown)
application.register('checkbox-select-all', CheckboxSelectAll)

// Configure Stimulus development experience
application.debug = false
window.Stimulus   = application

export { application }
