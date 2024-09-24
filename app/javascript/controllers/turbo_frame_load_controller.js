import { Controller } from "@hotwired/stimulus";

// Add it to your turbo-frame modal/slide-over like so:
// `turbo_frame_tag "modal", data: {controller: "turbo-frame-load", turbo_frame_load_paths_value: {settings: settings_path, notifications: notifications_path}}`
// Upon loading an URL like: “localhost:3000?v=settings` it will load the `settings_path` in the turbo-frame
//
export default class extends Controller {
  static values = {
    paramName: { type: String, default: "v" },
    paths: Object
  };

  connect() {
    if (this.#isInvalidParam) { return; }

    this.element.src = this.pathsValue[this.#param];
  }

  // private

  get #isInvalidParam() {
    return !this.#param && !this.pathsValue[this.#param];
  }

  get #param() {
    return this.#params.get(this.paramNameValue);
  }

  get #params() {
    return new URLSearchParams(window.location.search);
  }
}
