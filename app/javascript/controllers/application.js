import { Application } from "@hotwired/stimulus"
import Clipboard from 'stimulus-clipboard'
import CheckboxSelectAll from 'stimulus-checkbox-select-all'
import RevealController from '@stimulus-components/reveal'

import { Tabs, Slideover, Dropdown } from 'tailwindcss-stimulus-components'

import Sortable from '@stimulus-components/sortable'

const application = Application.start()

application.register('clipboard', Clipboard)
application.register('tabs', Tabs)
application.register('slideover', Slideover)
application.register('dropdown', Dropdown)
application.register('checkbox-select-all', CheckboxSelectAll)
application.register('reveal', RevealController)
application.register('sortable', Sortable)


// Configure Stimulus development experience
application.debug = false
window.Stimulus   = application

export { application }


