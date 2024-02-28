import Clipboard from 'stimulus-clipboard';
    
// Connects to data-controller="tax-trix-clipboard"
export default class extends Clipboard {
  connect() {
    super.connect()
  }
  
  copy(e) {
    e.preventDefault();
    const s = this.sourceTarget.querySelector("div").textContent || this.sourceTarget.value;
    navigator.clipboard.writeText(s).then((()=>this.copied()))
  }

  // Function to override when to input is copied.
  copied() {
    this.hasButtonTarget && (this.timeout && clearTimeout(this.timeout),
    this.buttonTarget.innerHTML = this.successContentValue,
    this.timeout = setTimeout((()=>{
        this.buttonTarget.innerHTML = this.originalContent
    }
    ), this.successDurationValue))
  }
}


