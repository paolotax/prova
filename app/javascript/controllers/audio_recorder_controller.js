import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["startButton", "stopButton", "audioPlayback", "audioInput", "recordingIndicator"];

  connect() {
    this.mediaStream = null;
    this.mediaRecorder = null;
    this.audioChunks = [];
    this.initializeMediaStream();
  }

  async initializeMediaStream() {
    try {
      // Ottieni il flusso al caricamento della pagina
      this.mediaStream = await navigator.mediaDevices.getUserMedia({ audio: true });
      const mimeType = MediaRecorder.isTypeSupported("audio/mp4") ? "audio/mp4" : "audio/webm";
      this.mediaRecorder = new MediaRecorder(this.mediaStream, { mimeType });

      this.mediaRecorder.ondataavailable = (event) => {
        this.audioChunks.push(event.data);
      };

      this.mediaRecorder.onstop = () => {
        const audioBlob = new Blob(this.audioChunks, { type: this.mediaRecorder.mimeType });
        this.audioChunks = [];
        const audioUrl = URL.createObjectURL(audioBlob);
        this.audioPlaybackTarget.src = audioUrl;

        // Prepara il file per il caricamento
        const file = new File([audioBlob], `recording.${this.mediaRecorder.mimeType.split("/")[1]}`, {
          type: this.mediaRecorder.mimeType,
        });
        const dataTransfer = new DataTransfer();
        dataTransfer.items.add(file);
        this.audioInputTarget.files = dataTransfer.files;

        // Nascondi l'indicatore di registrazione
        this.recordingIndicatorTarget.classList.add("hidden");
      };
    } catch (error) {
      console.error("Errore nell'accesso al microfono:", error);
      alert("Impossibile accedere al microfono. Controlla le impostazioni del dispositivo.");
    }
  }

  startRecording() {
    if (this.mediaRecorder) {
      this.audioChunks = [];
      this.mediaRecorder.start();

      // Aggiorna i pulsanti e l'indicatore
      this.startButtonTarget.disabled = true;
      this.stopButtonTarget.disabled = false;
      this.recordingIndicatorTarget.classList.remove("hidden");
    }
  }

  stopRecording() {
    if (this.mediaRecorder && this.mediaRecorder.state === "recording") {
      this.mediaRecorder.stop();

      // Aggiorna i pulsanti
      this.startButtonTarget.disabled = false;
      this.stopButtonTarget.disabled = true;
    }
  }

  disconnect() {
    if (this.mediaStream) {
      this.mediaStream.getTracks().forEach((track) => track.stop());
    }
  }
}