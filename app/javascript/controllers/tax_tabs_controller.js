import { Tabs } from 'tailwindcss-stimulus-components'

// Connects to data-controller="tax-tabs"
export default class extends Tabs {
  
  connect() {
    super.connect()
  }

  change(event) {
    super.change(event)
  }

  previousTab(event) {
    super.previousTab(event)
  }

  nextTab(event) {
    super.nextTab(event)
  }

  firstTab(event) {
    super.firstTab(event)
  }

  lastTab(event) {
    super.lastTab(event)
  }

}
