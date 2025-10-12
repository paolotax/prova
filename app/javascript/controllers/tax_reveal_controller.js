import Reveal from '@stimulus-components/reveal'

export default class extends Reveal {

  static targets = ["chevron"];

  connect() {
    super.connect()
    // this.restoreState()
  }

  disconnect() {
    this.saveState()
    super.disconnect()
  }

  toggle(e) {
    super.toggle()
    e.preventDefault()
    this.chevronTarget.classList.toggle('rotate-90')
    this.saveState()
  }

  saveState() {
    const sectionId = this.element.closest('li')?.querySelector('a')?.href?.split('/').pop() || 'unknown'
    const isOpen = !this.itemTarget.classList.contains('hidden')
    sessionStorage.setItem(`tax-reveal-${sectionId}`, isOpen.toString())
  }

  restoreState() {
    const sectionId = this.element.closest('li')?.querySelector('a')?.href?.split('/').pop() || 'unknown'
    const wasOpen = sessionStorage.getItem(`tax-reveal-${sectionId}`) === 'true'

    if (wasOpen && this.itemTarget.classList.contains('hidden')) {
      this.itemTarget.classList.remove('hidden')
      this.chevronTarget.classList.add('rotate-90')
    }
  }
}
