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

// document.addEventListener('turbo:frame-load', function(event) {
//     if (event.target.id === "search_results") {
//         // Trova e modifica i link esterni al turbo_frame
//         var externalLinkContainer = document.getElementById("button-excel-libri");
//         var externalLink1 = externalLinkContainer.querySelector("a");

//         var params = window.location.search;

//         // Modifica gli href dei link esterni
//         if (externalLink1) {
//             externalLink1.href = "/libri.xlsx" + params;
//         }
//     }
// });

