# Audit di preparazione alla commercializzazione di Scagnozz

Stato: prima ricognizione tecnica e documentale  
Data: 11 luglio 2026  
Ambito: applicazione Rails `prova`, API/MCP, CLI e dataset ministeriali

> Questo documento e le future bozze legali non costituiscono parere legale.
> Prima della commercializzazione devono essere validati da un professionista
> privacy/legale e completati con i dati reali del titolare del trattamento.

## Sintesi

Scagnozz è oggi utilizzabile come beta privata da un gruppo ristretto, ma non è
ancora pronto per una vendita generalizzata. Le funzionalità applicative,
l'isolamento logico per account e il deploy automatizzato costituiscono una
buona base. Mancano però documentazione legale pubblica, governance dei dati,
OAuth per le integrazioni di terze parti, procedure verificabili di export e
cancellazione, una politica di conservazione, inventario formalizzato dei
fornitori e alcuni hardening di sicurezza.

Priorità immediate:

1. impedire che token API compaiano negli URL e nei log;
2. verificare e rendere privati gli allegati S3 che non devono essere pubblici;
3. pubblicare informativa privacy e pagina fonti/licenze dati;
4. documentare fornitori, localizzazione e trasferimenti dei dati;
5. definire retention, cancellazione, export e ripristino da backup;
6. introdurre OAuth e scope separati per le integrazioni AI destinate a terzi.

## 1. Dati e interessati

### Dati gestiti dall'applicazione

- account, utenti, membership, sessioni e link di accesso;
- profilo personale, email, numero di cellulare e avatar;
- scuole, clienti, persone/insegnanti e relativi recapiti;
- appunti, allegati, immagini, note vocali e trascrizioni;
- documenti commerciali, righe, consegne, pagamenti e riferimenti;
- itinerari, tappe, geolocalizzazione e preferenze di navigazione;
- conversazioni AI, messaggi e richieste inviate ai tool;
- log tecnici, audit applicativo, errori, IP e user agent;
- access token e data dell'ultimo utilizzo.

### Interessati potenziali

- utenti e collaboratori dell'organizzazione cliente;
- clienti, referenti scolastici, insegnanti e altre persone registrate;
- contatti contenuti in documenti, allegati o importazioni;
- visitatori del sito e utenti delle integrazioni AI.

### Decisioni ancora necessarie

- titolare del trattamento, sede, P.IVA/CF e contatto privacy;
- ruoli privacy tra Scagnozz e organizzazioni clienti;
- basi giuridiche per ciascuna finalità;
- categorie di interessati e dati che i clienti sono autorizzati a importare;
- tempi di conservazione per dati attivi, account chiusi, log e backup.

## 2. Open Data del Ministero dell'Istruzione e del Merito

### Fonte effettivamente utilizzata

Il codice scarica i CSV dal Portale Unico dei Dati della Scuola, area
"Adozioni libri di testo", usando il catalogo:

- `https://dati.istruzione.it/opendata/opendata/catalogo/elements1/?area=Adozioni%20libri%20di%20testo`
- implementazione: `app/services/miur/adozioni_scraper.rb` e
  `lib/tasks/scrape_libri.rake`;
- i dati vengono importati, deduplicati, storicizzati per anno scolastico e
  utilizzati per statistiche, confronti e riconciliazioni;
- i CSV originali sono conservati nel volume production `/root/miur_data`.

I dataset regionali dichiarano licenza **Italian Open Data License 2.0
(IODL 2.0)**. La licenza consente utilizzo, modifica, creazione di lavori
derivati e riuso anche commerciale.

### Obblighi IODL 2.0 da rispettare

- indicare la fonte e il nome del licenziante;
- includere, quando possibile, copia o collegamento alla licenza;
- non suggerire che i risultati di Scagnozz siano ufficiali o approvati dal
  Ministero;
- adottare misure ragionevoli per non trarre in inganno e non travisare i dati;
- rispettare le ulteriori norme applicabili, inclusa la protezione dei dati
  personali.

### Attribuzione proposta

> Dati sulle adozioni dei libri di testo e sull'anagrafe scolastica tratti dal
> Portale Unico dei Dati della Scuola del Ministero dell'Istruzione e del
> Merito, riutilizzati ai sensi della Italian Open Data License 2.0 (IODL 2.0).
> Scagnozz elabora, normalizza, deduplica, storicizza e aggrega i dati originali.
> I risultati non hanno carattere ufficiale e Scagnozz non è affiliato né
> approvato dal Ministero. Per il dato ufficiale consultare la fonte originale.

### Interventi richiesti

- creare una pagina pubblica `/fonti-e-licenze`;
- mostrare attribuzione, link alla fonte e link al testo IODL 2.0;
- esporre anno scolastico, ultimo aggiornamento e stato stale/fallback vicino
  alle statistiche MIUR;
- distinguere sempre dati ministeriali originali da elaborazioni Scagnozz;
- conservare metadati di provenienza e data di download per ogni snapshot;
- non usare denominazioni, loghi o testi che suggeriscano ufficialità;
- verificare periodicamente che fonte e licenza dichiarata non siano cambiate.

### Valutazione preliminare

Il riuso commerciale appare consentito dalla IODL 2.0. L'obbligo principale è
l'attribuzione corretta, accompagnata dalla trasparenza sulle elaborazioni e
dall'assenza di qualsiasi implicazione di approvazione ministeriale. Questa
valutazione deve essere confermata nella revisione legale finale, soprattutto
se il prodotto redistribuirà estratti consistenti del dataset anziché soli
risultati aggregati.

## 3. Integrazioni AI e API

### Stato attuale

- endpoint MCP remoto: `/api/mcp`;
- autenticazione con access token via Bearer o parametro `api_key`;
- tool di lettura e scrittura registrati con annotation MCP;
- CLI con server MCP stdio per Claude, Codex e altri client;
- ChatGPT Pro limita i custom MCP privati a lettura/fetch;
- GPT Actions possono usare le API REST con API key Bearer;
- OpenAI e servizi AI possono ricevere prompt e parametri necessari alle azioni.

### Rischi rilevati

- i token `AccessToken` sono memorizzati in chiaro nel database;
- il parametro `api_key` nell'URL può apparire nella request line dei log anche
  se Rails filtra i parametri applicativi;
- non risultano scope distinti per lettura, scrittura ed eliminazione;
- non risulta un audit log dedicato alle chiamate MCP/API con attore, tool,
  account, esito e conferma;
- non esiste OAuth per collegare in sicurezza account di utenti terzi;
- manca una policy pubblica che spieghi quali dati vengono inviati ai provider
  AI e su iniziativa di chi.

### Interventi richiesti

- dismettere i token in query string e accettare solo header Bearer;
- memorizzare un digest del token, mostrando il segreto una sola volta;
- aggiungere scadenza, revoca, rotazione, scope e ultimo IP/client;
- separare scope `read`, `write` e `delete`;
- introdurre OAuth 2.1/OIDC per integrazioni multiutente;
- registrare le azioni AI senza salvare segreti o payload eccedenti;
- chiedere conferma esplicita per creazioni, modifiche, invii ed eliminazioni;
- documentare OpenAI, Anthropic e ogni altro provider effettivamente usato.

## 4. Sicurezza e isolamento dei clienti

### Punti positivi

- dominio applicativo prevalentemente scoped per `account_id`;
- membership e token sono collegati all'account;
- uso di Pundit, Rack Attack, SSL e secret di deploy separati;
- database e Redis non sono pubblicati direttamente su Internet;
- tool MCP impostano `Current.user` e `Current.account` dal token autenticato.

### Gap da verificare o correggere

- `AccountScoped` imposta automaticamente l'account in creazione, ma non
  impedisce da solo query cross-account: serve audit sistematico di controller,
  job, policy, admin, export e query SQL;
- verificare autorizzazioni Avo, Blazer, Sidekiq e rails_performance;
- aggiungere test automatici cross-tenant sulle risorse sensibili;
- definire MFA o autenticazione rafforzata per amministratori;
- definire ciclo di patching, vulnerability scanning e secret rotation;
- formalizzare gestione incidenti e data breach;
- classificare le azioni AI distruttive e applicare least privilege.

## 5. Storage, allegati e backup

### Evidenze

- Active Storage usa S3 `eu-central-1`;
- il servizio S3 è configurato con `public: true`;
- PostgreSQL dispone di backup containerizzati ogni 30 minuti;
- esiste uno script manuale di download del dump;
- i CSV ministeriali vivono in un volume host persistente separato;
- non è documentata una verifica periodica del restore.

### Interventi richiesti

- verificare immediatamente se allegati, avatar, documenti o note vocali sono
  raggiungibili pubblicamente; usare bucket privato e URL firmati dove serve;
- cifrare backup e allegati, definendo gestione delle chiavi;
- definire retention e rotazione dei backup;
- mantenere almeno una copia off-site/isolata;
- eseguire e registrare restore test periodici;
- includere allegati e configurazioni critiche nel piano di disaster recovery;
- definire RPO/RTO commerciali realistici.

## 6. Fornitori e trasferimenti

Provider individuati nel codice/configurazione, da confermare contrattualmente:

- hosting server e rete (attualmente host dedicato su IP production);
- Docker Hub per il registry delle immagini;
- AWS S3, regione `eu-central-1`, per gli allegati;
- Resend per email transazionali;
- Sentry per error tracking;
- OpenAI per trascrizione/chat e integrazioni ChatGPT;
- Anthropic quando gli utenti collegano Claude;
- Cloudflare Turnstile;
- provider di mappe/geocoding configurati dall'app;
- eventuali provider web push e servizi richiamati dagli import.

Per ogni fornitore occorre registrare finalità, categorie di dati, regione,
sub-responsabili, DPA, basi del trasferimento extra SEE, retention e procedura
di cancellazione.

## 7. Diritti, export, cancellazione e retention

### Gap rilevati

- non risulta un export completo dei dati dell'account o dell'utente;
- non risulta una procedura self-service di chiusura account;
- le associazioni `dependent: :destroy` coprono molte risorse, ma non
  costituiscono da sole una procedura verificata di cancellazione completa;
- non è definita la gestione di allegati, log, cache, job e backup dopo una
  richiesta di cancellazione;
- non sono documentati tempi di conservazione differenziati.

### Interventi richiesti

- inventario tabella-per-tabella e storage-per-storage;
- export portabile per account e interessato;
- workflow di cancellazione con anteprima, autorizzazione forte e audit;
- stato di sospensione prima della cancellazione irreversibile;
- policy di retention per dati attivi, cessati, fiscali, log e backup;
- procedura documentata per accesso, rettifica, limitazione e opposizione.

## 8. Documenti e pagine pubbliche necessarie

- Informativa privacy generale;
- informativa specifica per AI, MCP e GPT Actions;
- Termini e condizioni del servizio;
- Data Processing Agreement per clienti business, se applicabile;
- Cookie Policy e consent management se vengono introdotti cookie non tecnici;
- pagina Fonti e licenze dati;
- elenco/subprocessor list aggiornabile;
- policy di sicurezza e canale per segnalare vulnerabilità;
- condizioni di supporto, disponibilità, backup e manutenzione;
- policy di uso accettabile delle integrazioni AI.

## 9. Roadmap proposta

### Fase 0 — Beta privata sicura

- [ ] identità e contatti del titolare;
- [ ] privacy minima e fonti/licenze pubbliche;
- [ ] rimozione token dagli URL e dai log;
- [ ] rotazione dei token già esposti;
- [ ] verifica bucket S3 e allegati;
- [ ] inventario fornitori e DPA;
- [ ] restore test documentato;
- [ ] checklist di onboarding/offboarding colleghi.

### Fase 1 — Fondamenta commerciali

- [ ] audit cross-tenant e suite di test dedicata;
- [ ] export e cancellazione verificabili;
- [ ] retention automatizzata;
- [ ] ruoli e permessi commerciali;
- [ ] termini, DPA e subprocessor list;
- [ ] monitoraggio, incident response e vulnerability management;
- [ ] onboarding, supporto e gestione account.

### Fase 2 — Integrazioni e distribuzione

- [ ] OAuth e scope granulari;
- [ ] audit log delle azioni AI;
- [ ] GPT Actions private e test end-to-end;
- [ ] Apps SDK/plugin pubblico, se strategico;
- [ ] privacy policy e submission OpenAI;
- [ ] fatturazione, piani, quote e metriche di utilizzo.

### Fase 3 — Lancio

- [ ] validazione legale e privacy finale;
- [ ] test di sicurezza indipendente;
- [ ] test disaster recovery;
- [ ] documentazione utente e amministratore;
- [ ] canali assistenza e processo incidenti;
- [ ] checklist go-live e rollback.

## 10. Fonti di riferimento

- Portale Unico dei Dati della Scuola — dataset "Adozioni libri di testo";
- Italian Open Data License 2.0;
- Linee guida nazionali per la valorizzazione del patrimonio informativo
  pubblico, sezione licenze e attribuzione;
- GDPR, articoli 12–14 e indicazioni della Commissione europea;
- documentazione OpenAI per GPT Actions, app/plugin e pubblicazione.

I link definitivi dovranno essere riportati nelle pagine pubbliche e verificati
periodicamente.
