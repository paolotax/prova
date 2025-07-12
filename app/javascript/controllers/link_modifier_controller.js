import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
    
    static targets = ["link"]

    connect() {
        // Ascolta il caricamento del turbo_frame
        document.addEventListener('turbo:frame-load', this.modifyLinks.bind(this));
    }

    modifyLinks(event) {
        if (event.target.id === "search_results") {
            var params = window.location.search;

            this.linkTargets.forEach(link => {
                // Sostituisci o aggiungi i parametri senza duplicarli
                const baseUrl = link.href.split('?')[0];
                link.href = baseUrl + params;
            });
        }
    }
}


