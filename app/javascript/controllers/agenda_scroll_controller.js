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
          alert("Fetching previous week...");
          // this.loadPreviousWeek();
        } else if (trigger === "next") {
          
          this.loadNextWeek();

          // alert("Fetching next week...");
        }
      }
    });
  }

  loadNextWeek() {
    alert("Fetching next week...");
    
    this.loading = true;

    const lastElement = Array.from(this.weekContainerTarget.children).reverse().find(
      (child) => child.dataset.giorno
    );

    if (!lastElement) {
      console.error("No last day found in the container");
      this.loading = false;
      return;
    }

    const lastDay = lastElement.dataset.giorno;
    const nextWeekStart = new Date(lastDay);
    nextWeekStart.setDate(nextWeekStart.getDate() + 7);

    fetch(`/agenda?giorno=${nextWeekStart.toISOString().slice(0, 10)}&direction=append`, {
      headers: { Accept: "text/vnd.turbo-stream.html" },
    })
    .then((response) => response.text())
    .then((html) => {
      this.weekContainerTarget.insertAdjacentHTML("beforeend", html);
      this.addScrollTriggers(); // Ricrea i trigger
      this.loading = false;
    })
    .catch((error) => {
      console.error("Error loading next week:", error);
      this.loading = false;
    });
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