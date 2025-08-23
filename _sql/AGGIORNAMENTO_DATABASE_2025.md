# Aggiornamento Database 2025 - Guida Completa

## 📋 Panoramica

Questo documento descrive il sistema di aggiornamento automatico del database per l'anno scolastico 2025, implementato attraverso rake task che gestiscono l'integrazione di nuovi dati MIUR relativi a scuole e adozioni.

## 🎯 Obiettivo

L'aggiornamento serve per:
- Integrare nuove scuole dall'anno scolastico 2025/26
- Aggiornare i dati delle scuole esistenti
- Trasferire e deduplicare le adozioni tra le diverse tabelle
- Ricostruire le viste materializzate per garantire coerenza dei dati

## 📁 File Coinvolti

### Script SQL
- `_sql/2025_01_aggiorna_scuole.sql` - Aggiornamento dati scuole
- `_sql/2025_02_scorri_adozioni.sql` - Gestione trasferimento adozioni

### Rake Task
- `lib/tasks/database_update.rake` - Task di orchestrazione

## 🔧 Script SQL Dettagliati

### 1. Script Aggiornamento Scuole (`2025_01_aggiorna_scuole.sql`)

```sql
BEGIN;

-- Inserimento nuove scuole
INSERT INTO import_scuole (...)
SELECT ... FROM new_scuole ns
WHERE NOT EXISTS (
    SELECT 1 FROM import_scuole i
    WHERE i."CODICESCUOLA" = ns.codice_scuola
);

-- Aggiornamento scuole esistenti
UPDATE import_scuole SET ...
FROM new_scuole ns
WHERE import_scuole."CODICESCUOLA" = ns.codice_scuola;

COMMIT;
```

**Operazioni:**
- Inserisce solo scuole non presenti in `import_scuole`
- Aggiorna tutte le scuole esistenti con i nuovi dati
- Utilizza transazione per garantire atomicità

### 2. Script Gestione Adozioni (`2025_02_scorri_adozioni.sql`)

```sql
BEGIN;

-- 1) Trasferimento da import_adozioni a old_adozioni con deduplicazione
WITH deduplicated_import_adozioni AS (...)
INSERT INTO old_adozioni (...) 
ON CONFLICT (...) DO UPDATE SET ...;

-- 2) Svuotamento import_adozioni
DELETE FROM import_adozioni;

-- 3) Riempimento import_adozioni da new_adozioni (deduplicate)
WITH deduplicated_new_adozioni AS (...)
INSERT INTO import_adozioni (...);

COMMIT;
```

**Operazioni:**
- Trasferisce adozioni da `import_adozioni` a `old_adozioni` con deduplicazione
- Svuota `import_adozioni` 
- Riempie `import_adozioni` con dati deduplicate da `new_adozioni`
- Gestisce conflitti con UPSERT

## 🚀 Rake Task Disponibili

### Task Principale: `db_update:scuole_e_adozioni`

```bash
# Con conferma utente
docker exec -it prova-app-1 bin/rails db_update:scuole_e_adozioni

# Senza conferma (automatico)
docker exec -it prova-app-1 bin/rails db_update:scuole_e_adozioni[true]
```

**Fasi di esecuzione:**

#### FASE 1: Aggiornamento Scuole (~1.1 secondi)
- Esegue `2025_01_aggiorna_scuole.sql`
- Inserisce nuove scuole
- Aggiorna dati scuole esistenti
- Mostra statistiche di aggiornamento

#### FASE 2: Gestione Adozioni (~164 secondi)
- Esegue `2025_02_scorri_adozioni.sql`
- Trasferisce e deduplica milioni di record
- Gestisce integrità referenziale

#### FASE 3: Verifiche Finali (~2.6 secondi)
- Conta record nelle tabelle principali
- Calcola copertura scuole nelle adozioni
- Verifica integrità dei dati

#### FASE 4: Ricostruzione Viste (~5.2 secondi)
- Ricostruisce vista materializzata `view_classi`
- Aggiorna indici e statistiche

### Task Specifici

#### Solo Aggiornamento Scuole
```bash
docker exec -it prova-app-1 bin/rails db_update:solo_scuole
```

#### Solo Gestione Adozioni
```bash
docker exec -it prova-app-1 bin/rails db_update:solo_adozioni
```

#### Solo Ricostruzione Viste
```bash
docker exec -it prova-app-1 bin/rails db_update:refresh_views
```

#### Verifica Stato Database
```bash
docker exec -it prova-app-1 bin/rails db_update:verifica
```

## 📊 Risultati Tipici

### Statistiche Pre-Aggiornamento
- `new_scuole`: ~63.100 record
- `import_scuole`: ~69.200 record
- `new_adozioni`: ~3.539.000 record
- `import_adozioni`: ~3.538.000 record

### Statistiche Post-Aggiornamento
- `import_scuole`: ~68.100 record (aggiornate)
- `old_adozioni`: ~7.061.000 record
- `import_adozioni`: ~3.538.000 record (rinnovate)
- Copertura scuole: **99.3%** delle adozioni hanno scuola collegata

### Prestazioni
- **Tempo totale**: ~173 secondi (2.9 minuti)
- **Record elaborati**: >10 milioni
- **Efficienza**: ~58.000 record/secondo

## ⚠️ Considerazioni Importanti

### Sicurezza
- Tutti gli script utilizzano transazioni (`BEGIN;` / `COMMIT;`)
- Rollback automatico in caso di errori
- Conferma utente richiesta per operazioni critiche

### Deduplicazione
La chiave di deduplicazione per le adozioni è:
```sql
(anno_scolastico, codicescuola, annocorso, sezioneanno, combinazione, codiceisbn)
```

### Gestione Errori
- Logging completo di tutte le operazioni
- Interruzione immediata in caso di errore
- Messaggi di errore dettagliati

## 🔄 Quando Eseguire l'Aggiornamento

### Momento Ideale
- **Dopo** aver salvato e modificato gli appunti
- **Prima** di iniziare nuove elaborazioni
- Durante orari di basso traffico (es. notte)

### Frequenza
- Una volta per anno scolastico
- Dopo ogni importazione di nuovi dati MIUR
- Quando richiesto per allineamento dati

## 📝 Log e Monitoraggio

### Output del Task
```
=== FASE 1: Aggiornamento import_scuole con dati da new_scuole ===
✅ Script scuole eseguito con successo
📊 Totale scuole in import_scuole: 68.139
🔄 Scuole aggiornate negli ultimi 60 secondi: 63.278
✅ Aggiornamento scuole completato in 1.09 secondi

=== FASE 2: Trasferimento adozioni tra tabelle ===
✅ Script adozioni eseguito con successo
✅ Gestione adozioni completata in 163.89 secondi

=== FASE 3: Verifiche finali ===
📊 Totale record verificati
🎯 99.3% copertura scuole nelle adozioni
✅ Verifiche completate in 2.59 secondi

=== FASE 4: Ricostruzione viste materializzate ===
✅ Vista view_classi aggiornata con successo
📊 Classi nella vista: 346.606
✅ Ricostruzione viste completata in 5.19 secondi

🎉 AGGIORNAMENTO COMPLETATO in 167.57 secondi totali
```

### File di Log
- `log/development.log` - Log dettagliato delle operazioni
- `log/production.log` - Log di produzione (se applicabile)

## 🛠️ Troubleshooting

### Errori Comuni

#### Tabelle Mancanti
```
File non trovato: _sql/2025_01_aggiorna_scuole.sql
```
**Soluzione:** Verificare che i file SQL siano presenti nella cartella `_sql/`

#### Errori di Transazione
```
ERRORE nello script scuole: relation "new_scuole" does not exist
```
**Soluzione:** Assicurarsi che le tabelle `new_scuole` e `new_adozioni` siano popolate

#### Timeout Database
```
PG::QueryCanceled: canceling statement due to statement timeout
```
**Soluzione:** Eseguire durante orari di basso carico o aumentare timeout

### Verifica Integrità

Prima dell'aggiornamento:
```bash
docker exec -it prova-app-1 bin/rails db_update:verifica
```

Dopo errori:
```sql
-- Verifica tabelle vuote
SELECT 'new_scuole' as tabella, COUNT(*) FROM new_scuole
UNION ALL
SELECT 'new_adozioni', COUNT(*) FROM new_adozioni;

-- Verifica duplicati
SELECT COUNT(*), codice_scuola 
FROM new_scuole 
GROUP BY codice_scuola 
HAVING COUNT(*) > 1;
```

## 📈 Ottimizzazioni Future

### Performance
- Partizionamento tabelle per anno scolastico
- Indici ottimizzati per query di deduplicazione
- Esecuzione parallela per tabelle indipendenti

### Funzionalità
- Backup automatico pre-aggiornamento
- Notifiche email al completamento
- Dashboard di monitoraggio in tempo reale

## 👥 Contatti e Supporto

Per problemi o domande:
- Verificare i log di sistema
- Consultare questa documentazione
- Contattare il team di sviluppo

---

**Ultima modifica:** Gennaio 2025  
**Versione:** 1.0  
**Autore:** Sistema di Aggiornamento Database Automatico
