import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["weekContainer"];

  connect() {
    console.log("AgendaScrollController connected");

    this.loading = false;

    // Crea un IntersectionObserver per gli elementi di trigger
    this.observer = new IntersectionObserver(this.handleIntersection.bind(this), {
      root: this.weekContainerTarget, // Il contenitore scrollabile
      rootMargin: "100px",
      threshold: 0.1, // Percentuale di visibilità per attivare il callback
    });

    // Aggiungi i trigger per il caricamento delle settimane
    this.addScrollTriggers();
  }

  addScrollTriggers() {

    // Aggiungi trigger all'inizio e alla fine del contenitore
    const firstTrigger = document.createElement("div");
    firstTrigger.dataset.trigger = "previous";
    firstTrigger.classList.add("scroll-trigger");
    this.weekContainerTarget.prepend(firstTrigger);

    const lastTrigger = document.createElement("div");
    lastTrigger.dataset.trigger = "next";
    lastTrigger.classList.add("scroll-trigger");
    this.weekContainerTarget.append(lastTrigger);

    // Osserva i trigger
    this.observer.observe(firstTrigger);
    this.observer.observe(lastTrigger);
 
    console.log("Scroll triggers added");
  }

  handleIntersection(entries) {
    entries.forEach((entry) => {
      if (entry.isIntersecting && !this.loading) {
        const trigger = entry.target.dataset.trigger;

        if (trigger === "previous") {
          console.log("Fetching previous week...");
          // this.loadPreviousWeek();
        } else if (trigger === "next") {
          console.log("Fetching next week...");
          this.loadNextWeek();
        }
      }
    });
  }

  loadNextWeek() {
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

    const firstElement = Array.from(this.weekContainerTarget.children).find(
      (child) => child.dataset.giorno
    );

    if (!firstElement) {
      console.error("No first day found in the container");
      this.loading = false;
      return;
    }

    const firstDay = firstElement.dataset.giorno;
    const previousWeekStart = new Date(firstDay);
    previousWeekStart.setDate(previousWeekStart.getDate() - 7);

    fetch(`/agenda?giorno=${previousWeekStart.toISOString().slice(0, 10)}&direction=prepend`, {
      headers: { Accept: "text/vnd.turbo-stream.html" },
    })
    .then((response) => response.text())
    .then((html) => {
      this.weekContainerTarget.insertAdjacentHTML("afterbegin", html);
      this.addScrollTriggers(); // Ricrea i trigger
      this.loading = false;
    })
    .catch((error) => {
      console.error("Error loading previous week:", error);
      this.loading = false;
    });
  }

  disconnect() {
    this.observer.disconnect(); // Disconnetti l'observer
  }
}