import Reveal from '@stimulus-components/reveal'

export default class extends Reveal {
  
  static targets = ["chevron"];

  connect() {
    super.connect()
    console.log('Do what you want here.')
  }

  toggle(e) {
    super.toggle()
    this.chevronTarget.classList.toggle('rotate-90')
  }
}
