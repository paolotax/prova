import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    pdfUrl: String,
    to: String,
    subject: String,
    body: String
  }

  send() {
    // 1. Scarica il PDF
    const link = document.createElement("a")
    link.href = this.pdfUrlValue
    link.download = ""
    document.body.appendChild(link)
    link.click()
    link.remove()

    // 2. Apri Outlook Web compose in nuovo tab
    setTimeout(() => {
      const e = encodeURIComponent
      const url = `https://outlook.office.com/mail/deeplink/compose?to=${e(this.toValue)}&subject=${e(this.subjectValue)}&body=${e(this.bodyValue)}`
      window.open(url, "_blank")
    }, 500)
  }
}
