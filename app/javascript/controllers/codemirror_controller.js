import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["editor", "input"]

  connect() {
    this.editor = CodeMirror.fromTextArea(this.inputTarget, {
      mode: 'text/x-sql',
      theme: 'monokai',
      lineNumbers: true,
      indentWithTabs: true,
      smartIndent: true,
      lineWrapping: true,
      matchBrackets: true,
      autofocus: true
    })

    this.editor.on('change', (cm) => {
      this.inputTarget.value = cm.getValue()
    })
  }

  disconnect() {
    if (this.editor) {
      this.editor.toTextArea()
    }
  }
}