# API Compliance & Security — Piano

## Priorità 1 — Sicurezza base
- [ ] Permessi read/write su AccessToken (come Fizzy)
- [ ] Rate limiting sugli endpoint API
- [ ] Audit log: tracciare chi chiama cosa e quando (token, endpoint, timestamp, IP)

## Priorità 2 — GDPR tecnico
- [ ] Scadenza opzionale su token (expires_at)
- [ ] Endpoint DELETE /api/v1/persone/:id (diritto all'oblio)
- [ ] Endpoint GET /api/v1/persone/:id/export (portabilità dati)
- [ ] Data minimization: opzione per escludere campi sensibili dalle risposte

## Priorità 3 — GDPR organizzativo
- [ ] Privacy policy per il trattamento dati via API
- [ ] Documentare base legale per il trattamento (consenso o legittimo interesse)
- [ ] Registro dei trattamenti
- [ ] Procedura per richieste di accesso/cancellazione
- [ ] Valutare necessità DPO
