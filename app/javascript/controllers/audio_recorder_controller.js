import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["startButton", "stopButton", "audioPlayback", "audioInput", "recordingIndicator"];

  connect() {
    this.mediaRecorder = null;
    this.audioChunks = [];
    this.setupMediaRecorder();
  }

  async setupMediaRecorder() {
    try {
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
      
      // Verifica il supporto del MIME type per iOS
      const mimeType = MediaRecorder.isTypeSupported("audio/mp4") 
        ? "audio/mp4" 
        : "audio/webm";

      this.mediaRecorder = new MediaRecorder(stream, { mimeType });

      // Gestisce i dati disponibili
      this.mediaRecorder.ondataavailable = (event) => {
        this.audioChunks.push(event.data);
      };

      // Gestisce la fine della registrazione
      this.mediaRecorder.onstop = () => {
        const audioBlob = new Blob(this.audioChunks, { type: mimeType });
        this.audioChunks = [];
        const audioUrl = URL.createObjectURL(audioBlob);

        // Aggiorna il player con l'audio registrato
        this.audioPlaybackTarget.src = audioUrl;

        // Allega il file Blob al campo input nascosto
        const file = new File([audioBlob], `recording.${mimeType.split("/")[1]}`, { type: mimeType });
        const dataTransfer = new DataTransfer();
        dataTransfer.items.add(file);
        this.audioInputTarget.files = dataTransfer.files;

        // Nasconde l'indicatore di registrazione
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

      // Feedback visivo
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
}