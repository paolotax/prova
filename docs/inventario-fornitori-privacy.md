# Inventario fornitori e servizi esterni — Scagnozz

Ultimo aggiornamento: 12 luglio 2026

> Documento operativo interno, non ancora validato da un consulente legale.
> L'inventario deriva dalla configurazione e dal codice dell'applicazione. Le
> informazioni contrattuali contrassegnate come "da confermare" devono essere
> verificate negli account intestati a Paolo Tassinari prima della
> commercializzazione.

## Ruoli

Paolo Tassinari, ditta individuale, è titolare del trattamento per la gestione
degli account, la sicurezza, l'assistenza e l'amministrazione del servizio.
Quando Scagnozz tratta per conto di un cliente dati di dipendenti, docenti,
referenti, scuole o clienti del cliente, Paolo Tassinari opera normalmente come
responsabile del trattamento e i fornitori sotto elencati diventano
sub-responsabili. Il ruolo definitivo deve essere descritto nel DPA con il
cliente.

## Fornitori che trattano dati dell'applicazione

| Fornitore / servizio | Uso verificato nel codice | Dati potenzialmente trattati | Area / trasferimenti | Stato e azioni |
| --- | --- | --- | --- | --- |
| **Hetzner Online GmbH** | Server di produzione, container applicativi, PostgreSQL, Redis, log e backup ogni 30 minuti | Tutti i dati applicativi, account, contatti, documenti, log, IP, token cifrati/segreti operativi e backup | Il server configurato è `116.203.224.90`; sede fisica e location del server sono da confermare nell'account Hetzner | **Critico.** Concludere il DPA dall'account Hetzner, registrare la location, verificare cifratura e retention dei backup. Hetzner precisa che il DPA non è automatico e si conclude nell'account: <https://docs.hetzner.com/general/company-and-policy/data-protection-at-hetzner/> |
| **Amazon Web Services — S3** | Active Storage, bucket `tax-prova-bucket`, regione `eu-central-1` (Francoforte) | Copertine pubbliche; allegati, avatar, audio, import e file utente privati; metadati tecnici degli oggetti | Regione UE Francoforte; possibili accessi/sub-responsabili extra SEE disciplinati dal DPA/SCC | Il DPA AWS è incorporato nei termini e si applica automaticamente quando necessario: <https://docs.aws.amazon.com/whitepapers/latest/navigating-gdpr-compliance/aws-data-processing-addendum-dpa.html>. Verificare cifratura, Block Public Access, IAM, lifecycle e lista sub-responsabili: <https://aws.amazon.com/compliance/sub-processors/> |
| **Resend** | Invio di magic link, istruzioni CLI/estensione, notifiche e messaggi amministrativi | Indirizzo email, nome, contenuto e metadati del messaggio, IP/log di consegna | Società/servizi e sub-responsabili anche extra SEE; verificare la configurazione dell'account | Accettare/conservare il DPA e registrare i sub-responsabili. DPA: <https://resend.com/legal/dpa>; lista richiamata dal DPA: <https://resend.com/legal/subprocessors> |
| **OpenAI** | API per trascrizione audio, chat e generazione/interpretazione di appunti; integrazione con ChatGPT/MCP | Audio, trascrizioni, prompt, contenuti degli appunti e parametri delle azioni; possono includere nomi, contatti e dati commerciali inseriti dall'utente | OpenAI Ireland per clienti SEE secondo il DPA vigente; sub-responsabili e possibili trasferimenti disciplinati da DPA/SCC | **Critico.** Verificare che l'account/API usato sia business, accettare il DPA, controllare retention e impostazioni di condivisione dati, minimizzare i prompt. DPA vigente: <https://openai.com/policies/data-processing-addendum/>; sub-responsabili: <https://platform.openai.com/subprocessors> |
| **Sentry** | Raccolta errori Rails e Sidekiq in produzione | Stack trace, URL, release, breadcrumb HTTP e dati tecnici. `send_default_pii` è disattivato; payload applicativi o segreti potrebbero comunque comparire accidentalmente negli errori | Da confermare nel contratto/progetto Sentry, inclusa l'eventuale regione dati | Verificare piano, regione, retention, filtri/scrubbing e DPA; documentare la lista dei sub-responsabili. Il tracing e profiling sono disattivati nel codice. Non inviare token, contenuti o parametri sensibili. |
| **Mapbox** | Geocodifica di indirizzi, mappe e calcolo percorsi | Indirizzi di scuole/clienti, coordinate, punti del percorso, IP e dati tecnici del browser | Fornitore statunitense; trasferimenti e sub-responsabili da coprire con DPA/SCC | Accettare/verificare il DPA, limitare i dati inviati, verificare retention e telemetria. Sub-responsabili ufficiali: <https://www.mapbox.com/legal/subprocessors> |
| **Cloudflare Turnstile** | Protezione anti-bot della richiesta del magic link | IP, token Turnstile e segnali del browser/dispositivo necessari a distinguere utenti e bot | Cloudflare Inc.; trattamento distribuito e possibili trasferimenti internazionali | Inserire un riferimento specifico a Turnstile nell'informativa. Cloudflare dichiara di agire come responsabile per la protezione del sito e come titolare per il miglioramento del rilevamento: <https://www.cloudflare.com/turnstile-privacy-policy/>. DPA: <https://www.cloudflare.com/cloudflare-customer-dpa/> |

## Servizi caricati direttamente dal browser

Questi soggetti ricevono almeno IP, user agent, orario e normalmente il referrer
quando una pagina carica la loro risorsa. È preferibile ospitare localmente le
dipendenze statiche non indispensabili.

| Servizio | Uso | Valutazione / azione |
| --- | --- | --- |
| **jsDelivr** | Non più attivo: i pin esterni inutilizzati sono stati rimossi il 12 luglio 2026 | Nessuna chiamata runtime prevista; ricontrollare quando cambia l'importmap. |
| **cdnjs / Cloudflare** | Non più usato per CodeMirror dal 12 luglio 2026 | CodeMirror 5.65.7 e la licenza MIT sono conservati negli asset locali. |
| **UI Avatars** | Non più attivo dal 12 luglio 2026 | I placeholder sono SVG generati internamente, senza richieste esterne. |
| **Mapbox GL** | Libreria, stile e tile caricati da `api.mapbox.com` | Già compreso nella riga Mapbox; il browser comunica anche dati tecnici e coordinate/area visualizzata. |
| **Cloudflare Turnstile** | Script e iframe da `challenges.cloudflare.com` | Già compreso nella riga Turnstile; è necessario per la protezione del login. |

## Servizi attivati soltanto su scelta dell'utente

Scagnozz genera collegamenti verso Google Maps, Apple Maps, Waze e Outlook Web.
Il dato (per esempio indirizzo, coordinate, destinatario, oggetto e corpo email)
viene trasmesso al relativo fornitore quando l'utente apre il collegamento. Non
risultano API server-to-server verso questi servizi. Vanno descritti come servizi
terzi scelti dall'utente, non come sub-responsabili ordinari di Scagnozz.

ChatGPT/OpenAI e Claude/Anthropic possono inoltre collegarsi all'endpoint MCP su
iniziativa dell'utente. Il client AI tratta i prompt, i risultati e le azioni
mostrate nella propria interfaccia secondo il contratto dell'utente con quel
provider. L'applicazione usa direttamente OpenAI API, ma dal codice non risulta
un uso diretto delle API Anthropic da parte del server Scagnozz.

## Infrastruttura interna e soggetti non classificati come fornitori privacy

- PostgreSQL, Redis e Sidekiq sono eseguiti sul server Hetzner e non costituiscono
  fornitori separati.
- Il database GeoLite2 usato per la geolocalizzazione IP è locale; verificare
  soltanto licenza e procedura di aggiornamento MaxMind.
- Ahoy conserva dati analitici nel database dell'applicazione; il tracking
  JavaScript è disattivato e la geolocalizzazione IP usa il database locale.
- Docker Hub è usato come registry per il deploy. Normalmente riceve immagini,
  credenziali del registry e metadati tecnici di build/deploy, non i dati degli
  utenti finali. Va comunque protetto con credenziali dedicate e accesso minimo.
- Il Portale Open Data del Ministero dell'Istruzione è una fonte dati, non un
  responsabile del trattamento. La provenienza e la licenza IODL 2.0 sono già
  indicate nella pagina pubblica Fonti e licenze.
- I link esterni e le librerie citate soltanto nei commenti non sono stati
  considerati servizi attivi.

## Decisioni e verifiche ancora necessarie

- [ ] Confermare che `116.203.224.90` appartenga al contratto Hetzner e annotare
      data center/paese effettivo.
- [ ] Concludere e archiviare il DPA Hetzner nell'account della ditta.
- [ ] Salvare copia o prova di accettazione dei DPA AWS, Resend, OpenAI, Sentry,
      Mapbox e Cloudflare applicabili ai rispettivi account/piani.
- [ ] Registrare per ogni fornitore ragione sociale, sede, contatto privacy,
      regione dati, sub-responsabili, meccanismo di trasferimento, retention e
      data dell'ultima verifica.
- [ ] Verificare che Sentry sia realmente attivo e quale regione/retention usi.
- [ ] Verificare impostazioni OpenAI su conservazione, training/condivisione e
      abuse monitoring; impedire l'invio non necessario di dati personali.
- [ ] Verificare bucket policy, cifratura, IAM, lifecycle e completare la
      migrazione selettiva delle ACL S3 dopo il deploy del codice dedicato.
- [x] Ospitare localmente le dipendenze jsDelivr/cdnjs e sostituire UI Avatars.
- [ ] Aggiungere all'informativa pubblica una sezione nominativa sui destinatari,
      un riferimento specifico a Turnstile e informazioni più precise sui
      trasferimenti internazionali.
- [ ] Riesaminare l'inventario almeno annualmente e a ogni nuovo fornitore o
      integrazione.
