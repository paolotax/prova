import { Controller } from "@hotwired/stimulus";
import { get } from "@rails/request.js";

export default class extends Controller {
  static targets = ["weekContainer", "log"];
    
  connect() {
    console.log("AgendaScrollController connected");

    this.loading = false;

    // Abilita scroll e IntersectionObserver
    if ("IntersectionObserver" in window) {
      this.setupIntersectionObserver();
      // alert("IntersectionObserver supportato");
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
    leftTrigger.classList.add("scroll-trigger", "bg-red-500", "text-white", "w-12");
    this.weekContainerTarget.prepend(leftTrigger);

    const rightTrigger = document.createElement("div");
    rightTrigger.dataset.trigger = "next";
    rightTrigger.classList.add("scroll-trigger", "bg-red-500", "text-white", "w-12");
    this.weekContainerTarget.append(rightTrigger);

    this.observer.observe(leftTrigger);
    this.observer.observe(rightTrigger);
  }

  handleIntersection(entries) {
    entries.forEach((entry) => {
      if (entry.isIntersecting && !this.loading) {
        const trigger = entry.target.dataset.trigger;

        if (trigger === "previous") {
          console.log("Fetching previous week...");
          // this.loadPreviousWeek();
        } else if (trigger === "next") {          
          this.loadNextWeek();
          console.log("Fetching next week...");
        }
      }
    });
  }

  clearTriggers() {
    // Rimuovi i vecchi trigger
    this.weekContainerTarget.querySelectorAll(".scroll-trigger").forEach((trigger) => {
      trigger.remove();
    });
  };     

  async loadNextWeek() {

    this.loading = true;

    const lastElement = Array.from(this.weekContainerTarget.children).reverse().find(
      (child) => child.dataset.giorno
    );

    this.logTarget.textContent = `loadNextWeek: ${lastElement.dataset.giorno}`

    if (!lastElement) {
      console.error("No last day found in the container");
      this.loading = false;
      return;
    }

    const lastDay = new Date(lastElement.dataset.giorno);
    lastDay.setDate(lastDay.getDate() + 7);
    const url = `/agenda?giorno=${lastDay.toISOString().slice(0, 10)}&direction=append`;

    this.clearTriggers();

    try {
      const response = await get(url, {
        responseKind: "turbo-stream",
      });

      if (response.ok) {
        console.log("Next week loaded successfully.");
        this.addScrollTriggers();
      } else {
        console.error("Failed to load next week:", response);
      }
    } catch (error) {
      console.error("Error with request.js:", error);
    } finally {
      this.loading = false;
    }
  }

  loadPreviousWeek() {
    this.loading = true;
    console.log("Loading previous week...");
    // Fetch logica
  }

  disconnect() {
    if (this.observer) this.observer.disconnect();
    // this.weekContainerTarget.removeEventListener("scroll", this.handleScroll);
  }


}