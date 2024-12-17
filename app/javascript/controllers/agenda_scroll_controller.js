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
    this.observer = new IntersectionObserver(this.handleIntersection.bind(this), {
      root: this.weekContainerTarget,
      rootMargin: "0px",
      threshold: 0.1,
    });

    this.addScrollTriggers();
  }

  addScrollTriggers() {
    const leftTrigger = document.createElement("div");
    leftTrigger.dataset.trigger = "previous";
    leftTrigger.classList.add("scroll-trigger");
    this.weekContainerTarget.prepend(leftTrigger);

    const rightTrigger = document.createElement("div");
    rightTrigger.dataset.trigger = "next";
    rightTrigger.classList.add("scroll-trigger");
    this.weekContainerTarget.append(rightTrigger);

    this.observer.observe(leftTrigger);
    this.observer.observe(rightTrigger);
  }

  handleIntersection(entries) {
    entries.forEach((entry) => {
      if (entry.isIntersecting && !this.loading) {
        const trigger = entry.target.dataset.trigger;

        if (trigger === "previous") {
          alert("Fetching previous week...");
          // this.loadPreviousWeek();
        } else if (trigger === "next") {
          alert("Fetching next week...");
          // this.loadNextWeek();
        }
      }
    });
  }

}