import { Controller } from "@hotwired/stimulus";
import { get } from "@rails/request.js";

export default class extends Controller {
  static targets = ["weekContainer", "log"];
    
  connect() {
    console.log("AgendaScrollController connected");

    document.querySelector("#load-next").addEventListener("click", () => {
      this.loadNextWeek();
    });

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
    if (this.loading) return;
  
    this.loading = true;
    this.logTarget.textContent = "Starting loadNextWeek...";
  
    const lastElement = Array.from(this.weekContainerTarget.children).reverse().find(
      (child) => child.dataset.giorno
    );
  
    if (!lastElement) {
      this.logTarget.textContent = "Error: No last day found in the container.";
      this.loading = false;
      return;
    }
    console.log("Last element: ", lastElement.dataset.giorno);

    // Normalizza la data per Safari
    const lastDayString = this.normalizeDate(lastElement.dataset.giorno);
    console.log("Last day string: ", lastDayString);
    const lastDay = new Date(lastDayString);

    if (isNaN(lastDay.getTime())) {
      this.logTarget.textContent = `Error: Invalid date format (${lastElement.dataset.giorno})`;
      this.loading = false;
      return;
    }

    const nextWeekStart = new Date(lastDay);
    nextWeekStart.setDate(nextWeekStart.getDate() + 7);
    const url = `/agenda?giorno=${nextWeekStart.toISOString().slice(0, 10)}&direction=append`;

    this.logTarget.textContent = `Attempting to fetch URL: ${url}`;
  
    try {
      const response = await fetch(url, {
        headers: { Accept: "text/html" },
      });
  
      if (!response.ok) {
        this.logTarget.textContent = `Fetch failed: ${response.status}`;
        throw new Error(`Network response was not ok: ${response.status}`);
      }
  
      const html = await response.text();
      this.logTarget.textContent = "HTML successfully fetched.";
  
      this.weekContainerTarget.insertAdjacentHTML("beforeend", html);
      this.logTarget.textContent = "Next week loaded successfully.";
    } catch (error) {
      this.logTarget.textContent = `Error in fetch request: ${error.message}`;
    } finally {
      this.loading = false;
    }
  }
  
  calculateNextWeekDate() {
    const today = new Date();
    return today.toISOString().split("T")[0];
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

  normalizeDate(dateString) {
    if (/^\d{4}-\d{2}-\d{2}$/.test(dateString)) {
      return `${dateString}T00:00:00Z`;
    }
    return dateString;
  }

}