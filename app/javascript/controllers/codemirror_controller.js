import { Controller } from "@hotwired/stimulus"

const assetPromises = new Map()

export default class extends Controller {
  static targets = ["input"]
  static values = {
    mainScriptUrl: String,
    sqlScriptUrl: String,
    stylesheetUrl: String,
    themeUrl: String
  }

  async connect() {
    try {
      await Promise.all([
        this.loadStylesheet(this.stylesheetUrlValue),
        this.loadStylesheet(this.themeUrlValue)
      ])
      await this.loadScript(this.mainScriptUrlValue)
      await this.loadScript(this.sqlScriptUrlValue)

      if (this.element.isConnected) this.initializeEditor()
    } catch (error) {
      console.error("Unable to load CodeMirror", error)
    }
  }

  disconnect() {
    this.editor?.toTextArea()
    this.editor = null
  }

  initializeEditor() {
    if (this.editor || !window.CodeMirror) return

    this.editor = window.CodeMirror.fromTextArea(this.inputTarget, {
      mode: "text/x-sql",
      theme: "monokai",
      lineNumbers: true,
      indentWithTabs: true,
      smartIndent: true,
      lineWrapping: true,
      matchBrackets: true,
      autofocus: true
    })

    this.editor.on("change", (editor) => {
      this.inputTarget.value = editor.getValue()
    })
  }

  loadScript(url) {
    return this.loadAsset(url, () => {
      const script = document.createElement("script")
      script.src = url
      script.async = true
      return script
    })
  }

  loadStylesheet(url) {
    return this.loadAsset(url, () => {
      const link = document.createElement("link")
      link.rel = "stylesheet"
      link.href = url
      return link
    })
  }

  loadAsset(url, appendAsset) {
    if (assetPromises.has(url)) return assetPromises.get(url)

    const promise = new Promise((resolve, reject) => {
      const asset = appendAsset()
      asset.addEventListener("load", resolve, { once: true })
      asset.addEventListener("error", () => reject(new Error(`Failed to load ${url}`)), { once: true })
      document.head.appendChild(asset)
    })
    assetPromises.set(url, promise)
    return promise
  }
}
