# Feature: Area — raggruppamento direzioni dentro una provincia

## Problema
Alcuni account hanno metà provincia, oppure metà provincia con un gruppo editoriale e l'altra metà con 2 gruppi editoriali diversi. Le zone attuali (provincia + grado) non permettono questa granularità.

## Soluzione: campo `area` su Scuola e Mandato

### Concetto
- **Area** = etichetta stringa su `scuole` per raggruppare direzioni dentro una provincia
- Si assegna alla direzione, i plessi ereditano
- Il mandato può opzionalmente avere un'area → copre solo le scuole di quell'area
- Mandato senza area = copre tutta la provincia (comportamento attuale)
- L'area serve anche per raggruppare direzioni nei giri

### Esempio concreto — Rossi con metà provincia
- Roma Primaria: zona unica con tutte le scuole
- Mondadori: mandato su tutta Roma (area = null)
- Zanichelli: mandato solo su "Roma Nord" (area = "Roma Nord")
- DeAgostini: mandato solo su "Roma Nord" (area = "Roma Nord")

### Implementazione

#### 1. Migration
- Aggiungere `area` (string, nullable) a `scuole`
- Aggiungere `area` (string, nullable) a `mandati`

#### 2. UI assegnazione area alle direzioni
- Nella pagina scuole, campo editabile per direzione con autocomplete sulle aree già usate nella stessa provincia
- Quando si assegna area a una direzione, i plessi la ereditano (callback)

#### 3. Aggiornare UpdateMieAdozioniJob
- Aggiungere condizione: `AND (m.area IS NULL OR m.area = s.area)`
- Se mandato non ha area → copre tutto (come oggi)
- Se mandato ha area → filtra solo scuole di quell'area

#### 4. UI mandati — gestione per direzione
- L'interfaccia di creazione mandati NON cambia (si aggiunge gruppo a tutte le zone)
- Si aggiunge possibilità di restringere un mandato a un'area (per direzione/plessi)
- Dalla lista mandati, click su un mandato → mostra direzioni → possibilità di assegnare area

#### 5. Filtro area nei giri/tappe
- Filtro per area quando si creano tappe
- "Oggi faccio il giro di Roma Nord" → tutte le direzioni con area "Roma Nord"

### Cosa NON cambia
- Interfaccia zone (provincia + grado) resta identica
- Interfaccia base mandati (aggiungi gruppo per tutte le zone) resta identica
- `Accounts::Zona` non viene modificata
