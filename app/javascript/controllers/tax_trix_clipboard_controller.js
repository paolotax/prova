import Clipboard from 'stimulus-clipboard';
    
// Connects to data-controller="tax-trix-clipboard"
export default class extends Clipboard {
  
  static targets = ["button", "source"];
  static values = {
      successContent: String,
      successDuration: {
          type: Number,
          default: 2e3
      }
  }

  connect() {
    super.connect()
    if (window.isSecureContext) {
    } else {    
      this.buttonTarget.classList.add("hidden");
    }
  }
  
  copy(e) {
    e.preventDefault();
    const s = this.sourceTarget.querySelector("div").textContent || this.sourceTarget.value;
    navigator.clipboard
      .writeText(s)
      .then((() => this.copied()))
      .catch(() => { alert("something went wrong");});
  }

  // Function to override when to input is copied.
  copied() {
    this.hasButtonTarget && (this.timeout && clearTimeout(this.timeout),
    this.buttonTarget.innerHTML = this.successContentValue,
    
    this.buttonTarget.classList.remove("bg-yellow-300"),
    this.buttonTarget.classList.add("bg-cyan-500"),
    this.buttonTarget.classList.remove("text-yellow-800"),
    this.buttonTarget.classList.add("text-white"),
    
    this.timeout = setTimeout((()=>{
        
        this.buttonTarget.innerHTML = this.originalContent
        
        this.buttonTarget.classList.add("bg-yellow-300"),
        this.buttonTarget.classList.remove("bg-cyan-500"),
        this.buttonTarget.classList.add("text-yellow-800"),
        this.buttonTarget.classList.remove("text-white")
    }
    ), this.successDurationValue))
  }
}


