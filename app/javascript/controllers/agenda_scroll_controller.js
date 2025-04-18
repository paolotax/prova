import { Controller } from "@hotwired/stimulus";
import { get } from "@rails/request.js";

export default class extends Controller {
  static targets = ["weekContainer"];
    
  connect() {
    this.loading = false;

    // Abilita scroll e IntersectionObserver
    if ("IntersectionObserver" in window) {
      this.setupIntersectionObserver();
      // alert("IntersectionObserver supportato");
    } else {
      console.warn("IntersectionObserver non supportato, fallback su scroll.");
      // this.setupScrollListener();
      // alert("IntersectionObserver non supportato");
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
  
    const lastElement = Array.from(this.weekContainerTarget.children).reverse().find(
      (child) => child.dataset.giorno
    );
  
    if (!lastElement) {
      this.loading = false;
      return;
    }

    // Normalizza la data per Safari
    const lastDayString = this.normalizeDate(lastElement.dataset.giorno);
    const lastDay = new Date(lastDayString);
    if (isNaN(lastDay.getTime())) {
      this.loading = false;
      return;
    }

    const nextWeekStart = new Date(lastDay);
    nextWeekStart.setDate(nextWeekStart.getDate() + 7);
    const url = `/agenda?giorno=${nextWeekStart.toISOString().slice(0, 10)}&direction=append`;

    

    try {
      const response = await get(url, { responseKind: "turbo-stream" });

      if (response.ok) {
        
        
        // const turboStreamContent = await response.body; // Ottieni il contenuto come testo
        
        // console.log("Turbo Stream content:", response.body);

        // if (!turboStreamContent) {
        //   console.error("Empty Turbo Stream content received.");
        //   this.loading = false;
        //   return;
        // }

        // Turbo.renderStreamMessage(turboStreamContent);
        this.clearTriggers();
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

  normalizeDate(dateString) {
    if (/^\d{4}-\d{2}-\d{2}$/.test(dateString)) {
      return `${dateString}T00:00:00Z`;
    }
    return dateString;
  }

  async loadPreviousWeek() {
    if (this.loading) return;
  
    this.loading = true;
  
    // Trova il primo elemento visibile
    const firstElement = Array.from(this.weekContainerTarget.children).find(
      (child) => child.dataset.giorno
    );
  
    if (!firstElement) {
      this.loading = false;
      return;
    }
  
    const firstDayString = this.normalizeDate(firstElement.dataset.giorno);
    const firstDay = new Date(firstDayString);
  
    if (isNaN(firstDay.getTime())) {
      this.loading = false;
      return;
    }
  
    // Calcola la settimana precedente
    const previousWeekStart = new Date(firstDay);
    previousWeekStart.setDate(previousWeekStart.getDate() - 7);
    const url = `/agenda?giorno=${previousWeekStart.toISOString().slice(0, 10)}&direction=prepend`;
    

    // Turbo Stream is automatically handled, no need to call renderStreamMessage
        // Reposition scroll to account for prepending content
        const previousScrollHeight = this.weekContainerTarget.scrollHeight;

    try {
      const response = await get(url, { responseKind: "turbo-stream" });
  
      if (response.ok) {
        // const turboStreamContent = await response.body;
  
        // if (!turboStreamContent) {
        //   console.error("Empty Turbo Stream content received.");
        //   this.loading = false;
        //   return;
        // }
  
        // console.log("Turbo Stream Content for Previous Week:", turboStreamContent);
  
        this.clearTriggers();
  
        
        // this.weekContainerTarget.insertAdjacentHTML("afterbegin", turboStreamContent);
  
        const newScrollHeight = this.weekContainerTarget.scrollHeight;
        this.weekContainerTarget.scrollTop += newScrollHeight - previousScrollHeight;
  
        setTimeout(() => {
          this.addScrollTriggers();
        }, 50);
      } else {
        console.error("Failed to load previous week:", response);
      }
    } catch (error) {
      console.error("Error with request.js:", error);
    } finally {
      this.loading = false;
    }
  }

  disconnect() {
    if (this.observer) this.observer.disconnect();
    // this.weekContainerTarget.removeEventListener("scroll", this.handleScroll);
  }


}