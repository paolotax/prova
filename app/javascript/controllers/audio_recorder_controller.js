import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["startButton", "stopButton", "audioPlayback", "uploadButton", "recordingIndicator"];

  connect() {
    this.mediaRecorder = null;
    this.audioChunks = [];
    this.setupMediaRecorder();
  }

  async setupMediaRecorder() {
    try {
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
      this.mediaRecorder = new MediaRecorder(stream);

      this.mediaRecorder.ondataavailable = (event) => {
        this.audioChunks.push(event.data);
      };

      this.mediaRecorder.onstop = () => {
        const audioBlob = new Blob(this.audioChunks, { type: "audio/webm" });
        this.audioChunks = [];
        const audioUrl = URL.createObjectURL(audioBlob);
        this.audioPlaybackTarget.src = audioUrl;

        // Convert the audio blob to base64 and store it in the hidden input
        const reader = new FileReader();
        reader.readAsDataURL(audioBlob);
        reader.onloadend = () => {
          document.getElementById("audioBlobInput").value = reader.result;
        };

        // Nascondi l'indicatore di registrazione
        this.recordingIndicatorTarget.classList.add("hidden");
      };
    } catch (err) {
      console.error("Error accessing microphone:", err);
    }
  }

  startRecording() {
    if (this.mediaRecorder) {
      this.audioChunks = [];
      this.mediaRecorder.start();

      // Disabilita il pulsante di inizio e abilita quello di stop
      this.startButtonTarget.disabled = true;
      this.stopButtonTarget.disabled = false;

      // Mostra l'indicatore di registrazione
      this.recordingIndicatorTarget.classList.remove("hidden");
    }
  }

  stopRecording() {
    if (this.mediaRecorder) {
      this.mediaRecorder.stop();

      // Abilita il pulsante di inizio e disabilita quello di stop
      this.startButtonTarget.disabled = false;
      this.stopButtonTarget.disabled = true;
    }
  }
}