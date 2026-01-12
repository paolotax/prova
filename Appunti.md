# RISTRUTTURAZIONE DEL DATABASE per Scagnozz 2.0

## Scuole e Adozioni

stato attuale:

import_scuola ed import_adozione sono i modelli nei quali importo i dati dal ministero (new_scuole, new_adozioni, old_...) e dai quali genero una materialized_view per le classi. Tutti questi dati sono collegati all'user tramite la tabella user_scuole e alle adozioni dell'utente con la tabella mandato.

Obbiettivo

Creare dei modelli Multi Tennant in cui gli utenti importano 

Scuole, Adozioni e Classi dai dati principali globali import_... ecc

## Riorganizzazione app

le finalita di questa app sono: 

velocizzare l'inserimento di richieste ricevute telefonicamente per email, per whatsapp ( si può integrare? ) o a voce da parte di insegnanti, scuole, classi, clienti ecc... di libri in omaggio o in vendita.

Questi appunti devono poter contenere righe di libri dal db con prezzo quantita e sconto come al momento fanno i documenti.

per la gestione per ora ci sono documenti e righe che funzionano ma non hanno i test

la consegna dei kit insegnanti (legata)

@appunti, @ordini, @giri

# Appunti 

possono essere assegnati a chiunque: Scuola ( non ImportScuola ma Scuola), Classe, Persona (modello da aggiungere) Docente, Dirigente), Cliente, Comune ecc.

hanno i seguenti stati

- golden 
- closed
- not_now 
- draft 
- in_sospeso
- consegnato
- pagato
- registrato



