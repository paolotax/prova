import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["weekContainer"];
    
  connect() {
    console.log("AgendaScrollController connected");

    this.loading = false;

    // Abilita scroll e IntersectionObserver
    if ("IntersectionObserver" in window) {
      this.setupIntersectionObserver();
      alert("IntersectionObserver supportato");
    } else {
      console.warn("IntersectionObserver non supportato, fallback su scroll.");
      // this.setupScrollListener();
      alert("IntersectionObserver non supportato");
    }
  }

  setupIntersectionObserver() {
    // this.observer = new IntersectionObserver(this.handleIntersection.bind(this), {
    //   root: this.weekContainerTarget,
    //   rootMargin: "0px",
    //   threshold: 0.1,
    // });

    // this.addScrollTriggers();
  }

}