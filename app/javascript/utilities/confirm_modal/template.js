export class Template {
  constructor({theme = "light", message = "Are you sure you want to continue?", cancelLabel = "Cancel", confirmLabel = "Confirm"}) {
    this.theme = theme;
    this.message = message;
    this.cancelLabel = cancelLabel;
    this.confirmLabel = confirmLabel;
  }

  static styleConfig = {
    light: {
      container: "flex items-center justify-center fixed inset-0 w-full h-full z-10",
      content: "w-full max-w-lg bg-white rounded-lg shadow-xl ring-1 ring-offset-0 ring-gray-200",
      message: "px-3 py-4 font-normal text-gray-700",
      buttons: "flex justify-end items-center flex-wrap gap-3 px-3 py-2 bg-gray-50",
      button: "px-3 py-1 text-sm font-medium tracking-tight rounded-sm",
      confirmButton: "text-white bg-red-500 hover:bg-red-600",
      cancelButton: "text-gray-700 bg-gray-100 hover:bg-gray-200"
    },

    dark: {
      container: "flex items-center justify-center fixed inset-0 w-full h-full z-10",
      content: "w-full max-w-lg bg-gray-800 rounded-lg shadow-xl ring-1 ring-offset-0 ring-gray-900",
      message: "px-3 py-4 font-normal text-white",
      buttons: "flex justify-end items-center flex-wrap gap-3 px-3 py-2 bg-gray-700",
      button: "px-3 py-1 text-sm font-medium tracking-tight rounded-sm",
      confirmButton: "text-red-100 bg-red-700 hover:bg-red-600",
      cancelButton: "text-gray-100 bg-gray-700 hover:bg-gray-600"
    },

    lightGlass: {
      container: "flex items-center justify-center fixed inset-0 w-full h-full z-10",
      content: "w-full max-w-lg bg-white/50 backdrop-blur-md rounded-lg ring-1 ring-offset-0 ring-gray-200/70",
      message: "px-3 py-4 font-normal text-gray-800",
      buttons: "flex justify-end items-center flex-wrap gap-3 px-3 py-2 border-t border-gray-100",
      button: "px-3 py-1 text-sm font-medium tracking-tight rounded-sm",
      confirmButton: "text-white bg-red-500 hover:bg-red-600",
      cancelButton: "text-gray-700 bg-gray-100 hover:bg-gray-200"
    }
  }

  render() {
    return `
      <div id="confirm-modal" class="${this.#getClass('container')}">
        <div class="${this.#getClass('content')}">
          <p class="${this.#getClass('message')}">
            ${this.message}
          </p>

          <div class="${this.#getClass('buttons')}">
            <button data-behavior="cancel" class="${this.#getClass('button')} ${this.#getClass('cancelButton')}">
              ${this.cancelLabel}
            </button>

            <button data-behavior="commit" class="${this.#getClass('button')} ${this.#getClass('confirmButton')}">
              ${this.confirmLabel}
            </button>
          </div>
        </div>
      </div>
    `
  }

  // private

  #getClass(element) {
    return Template.styleConfig[this.theme][element];
  }
}
