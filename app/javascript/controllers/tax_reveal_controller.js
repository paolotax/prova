import Reveal from '@stimulus-components/reveal'

export default class extends Reveal {
  
  static targets = ["chevron"];

  connect() {
    super.connect()
  }

  toggle(e) {
    super.toggle()
    e.preventDefault()
    this.chevronTarget.classList.toggle('rotate-90')
  }
}
