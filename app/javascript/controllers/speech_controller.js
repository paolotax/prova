import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["output", "button", "label"]

  connect() {
    const SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition
    if (!SpeechRecognition) return

    this.recognition = new SpeechRecognition()
    this.recognition.lang = "it-IT"
    this.recognition.continuous = true
    this.recognition.interimResults = true

    this.recognition.onresult = (event) => {
      let finalTranscript = ""
      for (let i = event.resultIndex; i < event.results.length; i++) {
        if (event.results[i].isFinal) {
          finalTranscript += event.results[i][0].transcript
        }
      }
      if (finalTranscript) {
        const current = this.outputTarget.value
        const separator = current && !current.endsWith(" ") ? " " : ""
        this.outputTarget.value = current + separator + finalTranscript
      }
    }

    this.recognition.onerror = () => this.stop()
    this.recognition.onend = () => {
      if (this.listening) this.recognition.start()
    }

    this.listening = false
    this.buttonTarget.hidden = false
  }

  toggle() {
    this.listening ? this.stop() : this.start()
  }

  start() {
    this.listening = true
    this.recognition.start()
    this.buttonTarget.classList.add("btn--danger")
    this.labelTarget.textContent = "Stop"
  }

  stop() {
    this.listening = false
    this.recognition.stop()
    this.buttonTarget.classList.remove("btn--danger")
    this.labelTarget.textContent = "Microfono"
  }

  disconnect() {
    if (this.listening) this.stop()
  }
}
