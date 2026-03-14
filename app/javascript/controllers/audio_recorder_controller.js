import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button", "label", "recordings"]

  connect() {
    this.recording = false
    this.mediaRecorder = null
    this.chunks = []
    this.counter = 0
  }

  async toggle() {
    this.recording ? this.stop() : await this.start()
  }

  async start() {
    try {
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true })
      this.mediaRecorder = new MediaRecorder(stream)
      this.chunks = []

      this.mediaRecorder.ondataavailable = (e) => {
        if (e.data.size > 0) this.chunks.push(e.data)
      }

      this.mediaRecorder.onstop = () => {
        stream.getTracks().forEach(track => track.stop())
        const blob = new Blob(this.chunks, { type: "audio/webm" })
        this.addRecording(blob)
      }

      this.mediaRecorder.start()
      this.recording = true
      this.buttonTarget.classList.add("btn--danger")
      this.labelTarget.textContent = "Stop registrazione"
      this.startTimer()
    } catch (e) {
      console.error("Microphone access denied:", e)
    }
  }

  stop() {
    if (this.mediaRecorder && this.mediaRecorder.state === "recording") {
      this.mediaRecorder.stop()
    }
    this.recording = false
    this.buttonTarget.classList.remove("btn--danger")
    this.labelTarget.textContent = "Registra vocale"
    this.stopTimer()
  }

  addRecording(blob) {
    this.counter++
    const url = URL.createObjectURL(blob)
    const name = `vocale_${this.counter}.webm`

    const wrapper = document.createElement("div")
    wrapper.classList.add("flex", "align-center", "gap-half")

    const audio = document.createElement("audio")
    audio.src = url
    audio.controls = true
    audio.classList.add("flex-grow")

    const removeBtn = document.createElement("button")
    removeBtn.type = "button"
    removeBtn.classList.add("btn", "btn--small", "btn--ghost")
    removeBtn.textContent = "×"
    removeBtn.addEventListener("click", () => {
      wrapper.remove()
      URL.revokeObjectURL(url)
    })

    wrapper.appendChild(audio)
    wrapper.appendChild(removeBtn)
    this.recordingsTarget.appendChild(wrapper)

    // Add file to the form's file input
    const form = this.element.closest("form")
    if (form) {
      const file = new File([blob], name, { type: "audio/webm" })
      const dt = new DataTransfer()

      const existingInput = form.querySelector('input[name="appunto[attachments][]"]')
      if (existingInput && existingInput.files) {
        for (const f of existingInput.files) dt.items.add(f)
      }

      dt.items.add(file)
      if (existingInput) existingInput.files = dt.files
    }
  }

  startTimer() {
    this.seconds = 0
    this.timerInterval = setInterval(() => {
      this.seconds++
      const mins = Math.floor(this.seconds / 60).toString().padStart(2, "0")
      const secs = (this.seconds % 60).toString().padStart(2, "0")
      this.labelTarget.textContent = `Stop ${mins}:${secs}`
    }, 1000)
  }

  stopTimer() {
    if (this.timerInterval) clearInterval(this.timerInterval)
  }

  disconnect() {
    if (this.recording) this.stop()
  }
}
