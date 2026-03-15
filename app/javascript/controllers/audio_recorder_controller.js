import { Controller } from "@hotwired/stimulus"
import { DirectUpload } from "@rails/activestorage"

export default class extends Controller {
  static targets = ["button", "label", "recordings"]

  connect() {
    this.recording = false
    this.mediaRecorder = null
    this.chunks = []
    this.counter = 0
    this.mimeType = this.detectMimeType()
  }

  detectMimeType() {
    const types = ["audio/webm", "audio/mp4", "audio/ogg", "audio/wav"]
    return types.find(t => MediaRecorder.isTypeSupported(t)) || ""
  }

  get fileExtension() {
    const map = { "audio/webm": "webm", "audio/mp4": "m4a", "audio/ogg": "ogg", "audio/wav": "wav" }
    return map[this.mimeType] || "audio"
  }

  async toggle() {
    this.recording ? this.stop() : await this.start()
  }

  async start() {
    try {
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true })
      const options = this.mimeType ? { mimeType: this.mimeType } : {}
      this.mediaRecorder = new MediaRecorder(stream, options)
      this.chunks = []

      this.mediaRecorder.ondataavailable = (e) => {
        if (e.data.size > 0) this.chunks.push(e.data)
      }

      this.mediaRecorder.onstop = () => {
        stream.getTracks().forEach(track => track.stop())
        const type = this.mediaRecorder.mimeType || this.mimeType
        const blob = new Blob(this.chunks, { type })
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
    const name = `vocale_${this.counter}.${this.fileExtension}`

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

    wrapper.appendChild(audio)
    wrapper.appendChild(removeBtn)
    this.recordingsTarget.appendChild(wrapper)

    // Direct upload to Active Storage
    // Strip codec params from content type (e.g. "audio/webm;codecs=opus" → "audio/webm")
    // to avoid 422 from Active Storage disk service
    const contentType = blob.type.split(";")[0]
    const file = new File([blob], name, { type: contentType })
    const uploadUrl = "/rails/active_storage/direct_uploads"
    const upload = new DirectUpload(file, uploadUrl)

    upload.create((error, uploadedBlob) => {
      if (error) {
        console.error("Direct upload failed:", error)
        return
      }

      // Add hidden input with signed_id for the form
      const form = this.element.closest("form")
      if (form) {
        const hidden = document.createElement("input")
        hidden.type = "hidden"
        hidden.name = "appunto[attachments][]"
        hidden.value = uploadedBlob.signed_id
        hidden.dataset.recordingWrapper = "true"
        wrapper.appendChild(hidden)
      }

      removeBtn.addEventListener("click", () => {
        wrapper.remove()
        URL.revokeObjectURL(url)
      })
    })
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
