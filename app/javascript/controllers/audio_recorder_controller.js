import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["startControl", "recordingControls", "uploadControls"];

  connect() {
    this.mediaRecorder = null;
    this.audioChunks = [];
    this.initializeMediaRecorder();
    // this.showStartControls(); // Mostra solo i controlli di inizio all'avvio
  }

  async initializeMediaRecorder() {
    try {
      // Richiede l'accesso al microfono
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true });

      // Controlla il tipo MIME supportato
      const mimeType = MediaRecorder.isTypeSupported("audio/webm") ? "audio/webm" : "audio/mp4";

      // Configura MediaRecorder
      this.mediaRecorder = new MediaRecorder(stream, { mimeType });

      this.mediaRecorder.ondataavailable = (event) => {
        this.audioChunks.push(event.data);
      };

      this.mediaRecorder.onstop = () => {
        const audioBlob = new Blob(this.audioChunks, { type: mimeType });
        this.audioChunks = [];
        
        const file = new File([audioBlob], `recording.${mimeType.split("/")[1]}`, { type: mimeType });
        const formData = new FormData();
        formData.append('audio_file', file);

        fetch('/voice_notes', {
          method: 'POST',
          body: formData,
          headers: {
            'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content,
            'Accept': 'text/vnd.turbo-stream.html'
          }
        })
        .then(response => {
          if (response.ok) {
            return response.text();
          }
          throw new Error('Errore durante il salvataggio');
        })
        .then(html => {
          Turbo.renderStreamMessage(html);
          this.showStartControls();
        })
        .catch(error => {
          console.error('Errore:', error);
        });
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

      // Passa ai controlli di registrazione
      this.showRecordingControls();
    }
  }

  stopRecording() {
    if (this.mediaRecorder && this.mediaRecorder.state === "recording") {
      this.mediaRecorder.stop();
    }
  }

  resetForm(event) {
    if (event.detail.success) {
      this.showStartControls(); // Torna ai controlli di inizio
    } else {
      console.error("Errore durante il salvataggio della nota vocale.");
    }
  }

  // Gestione della visibilità dei controlli
  showStartControls() {
    this.startControlTarget.classList.remove("hidden");
    this.recordingControlsTarget.classList.add("hidden");
    // this.uploadControlsTarget.classList.add("hidden");
  }

  showRecordingControls() {
    this.startControlTarget.classList.add("hidden");
    this.recordingControlsTarget.classList.remove("hidden");
    // this.uploadControlsTarget.classList.add("hidden");
  }

  showUploadControls() {
    this.startControlTarget.classList.add("hidden");
    this.recordingControlsTarget.classList.add("hidden");
    // this.uploadControlsTarget.classList.remove("hidden");
  }
}