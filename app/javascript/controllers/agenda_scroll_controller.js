import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["weekContainer"];

  connect() {
    console.log("AgendaScrollController connected");

    // const container = this.weekContainerTarget;

    // // Posizionati sul giorno corrente
    // const todayElement = container.querySelector(`[data-giorno="${this.getToday()}"]`);
    // console.log(todayElement);
    // if (todayElement) {
    //   const offset = todayElement.offsetLeft;
    //   container.scrollLeft = offset; // Posizionati sul giorno corrente
    // }

    this.loading = false;
  }

  loadMore() {
    console.log("Scroll event detected");

    const container = this.weekContainerTarget;
    
    // console.log("ScrollLeft:", container.scrollLeft);
    // console.log("ScrollWidth:", container.scrollWidth);
    // console.log("OffsetWidth:", container.offsetWidth);

    // console.log("left + width:", container.scrollLeft + container.offsetWidth);
   

    if (this.debounceTimeout) clearTimeout(this.debounceTimeout);

    this.debounceTimeout = setTimeout(() => {
      const container = this.weekContainerTarget;
  
      const scrollRight =
        container.scrollLeft + container.offsetWidth >= container.scrollWidth - 100;
      const scrollLeft = container.scrollLeft <= 100;
  
      if (scrollRight && !this.loading) {
        console.log("Fetching next week...");
        this.loadNextWeek();
      } else if (scrollLeft && !this.loading) {
        console.log("Fetching previous week...");
        this.loadPreviousWeek();
      }
    }, 200); 
  }

  loadNextWeek() {
    if (this.loading) return; // Previeni caricamenti multipli

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

    this.loading = true; // Imposta il flag per evitare richieste multiple

    fetch(`/agenda?giorno=${nextWeekStart.toISOString().slice(0, 10)}&direction=append`, {
      headers: { Accept: "text/vnd.turbo-stream.html" },
    })
    .then((response) => response.text())
    .then((html) => {
      this.weekContainerTarget.insertAdjacentHTML("beforeend", html);
      this.loading = false; // Reimposta il flag
    })
    .catch((error) => {
      console.error("Error loading next week:", error);
      this.loading = false; // Reimposta il flag in caso di errore
    });
  }

  loadPreviousWeek() {
    if (this.loading) return;

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

    this.loading = true;
    
    console.log(firstDay);
    console.log(previousWeekStart.toISOString().slice(0, 10));
    fetch(`/agenda?giorno=${previousWeekStart.toISOString().slice(0, 10)}&direction=prepend`, {
      headers: { Accept: "text/vnd.turbo-stream.html" },
    })
      .then((response) => response.text())
      .then((html) => {
        this.weekContainerTarget.insertAdjacentHTML("afterbegin", html);

        const previousScrollWidth = this.weekContainerTarget.scrollWidth;
        const newContentWidth = this.weekContainerTarget.scrollWidth - previousScrollWidth;
        this.weekContainerTarget.scrollLeft += newContentWidth;

        this.loading = false;
      })
      .catch((error) => {
        console.error("Error loading previous week:", error);
        this.loading = false;
      });
  
  }

  getFirstDay() {
    const firstElement = Array.from(this.weekContainerTarget.children).find(
      (child) => child.dataset.giorno
    );
    console.log("First element:", firstElement);
    return firstElement ? firstElement.dataset.giorno : null;
  }

  getToday() {
    const today = new Date();
    return today.toISOString().split("T")[0];
  }
}