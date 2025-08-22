# Backup e Gestione Appunti SSK

## Panoramica
Questo sistema permette di fare il backup completo degli appunti SSK (Saggi, Seguiti, Kit) prima del passaggio all'anno scolastico successivo, preservando tutti i dati correlati (scuola, adozione, libro, classe, anno inserimento).

## Struttura Implementata

### 1. Tabella Backup: `ssk_appunti_backup`
Una nuova tabella che conserva tutti i dati degli appunti SSK in forma denormalizzata:
- **Dati originali dell'appunto**: ID originale, utente, nome, contenuto, stato, etc.
- **Dati scuola**: codice ministeriale, denominazione, comune, provincia, etc.
- **Dati adozione/libro**: ISBN, titolo, autori, editore, disciplina, prezzo, etc.
- **Dati classe**: anno corso, sezione, combinazione, tipo grado
- **Dati libro utente**: titolo, categoria, prezzo, note (se presente)
- **Anno scolastico di backup**: per tracciare quale anno è stato archiviato

### 2. Model: `SskAppuntoBackup`
Model per gestire i dati di backup con:
- Scopes per filtrare per utente, anno scolastico, tipo (saggio/seguito/kit)
- Metodo `backup_ssk_appunti!` per creare i backup automaticamente
- Metodi helper per visualizzare i dati (classe_e_sezione, scuola_e_citta, etc.)

### 3. Task Rake: `lib/tasks/ssk_backup.rake`
Suite completa di comandi per gestire il backup:

## Comandi Disponibili

### 📊 Visualizzare Statistiche
```bash
# Mostra statistiche appunti SSK attuali e backup
rails ssk:stats

# Per un anno specifico
rails ssk:stats[202526]
```

### 💾 Creare Backup
```bash
# Backup per l'anno corrente (202425)
rails ssk:backup

# Backup per un anno specifico
rails ssk:backup[202526]
```

### 🔍 Verificare Integrità Backup
```bash
# Verifica che tutti gli appunti SSK siano nel backup
rails ssk:verify_backup

# Per un anno specifico
rails ssk:verify_backup[202526]
```

### 🗑️ Eliminare Appunti Dopo Backup
```bash
# Elimina gli appunti SSK dopo aver verificato il backup
rails ssk:delete_after_backup

# Per un anno specifico
rails ssk:delete_after_backup[202526]
```

## Procedura Raccomandata per il Passaggio Anno

### 1. Prima del Passaggio Anno
```bash
# 1. Visualizza le statistiche attuali
rails ssk:stats

# 2. Crea il backup per l'anno che sta per finire
rails ssk:backup[202425]

# 3. Verifica l'integrità del backup
rails ssk:verify_backup[202425]
```

### 2. Dopo Aver Verificato il Backup
```bash
# 4. Solo dopo aver verificato che tutto sia corretto, elimina gli appunti
rails ssk:delete_after_backup[202425]

# 5. Verifica finale
rails ssk:stats
```

## Caratteristiche di Sicurezza

### ✅ Protezioni Implementate
- **Conferma utente**: Richiede conferma esplicita prima di eliminare
- **Verifica backup**: Controlla che esistano backup prima dell'eliminazione
- **Transazioni**: Usa transazioni database per rollback in caso di errore
- **Logging dettagliato**: Traccia tutte le operazioni
- **Controllo duplicati**: Evita backup duplicati dello stesso appunto
- **Eliminazione sicura**: Elimina solo appunti presenti nel backup

### 🔍 Controlli di Integrità
- Verifica che tutti gli appunti SSK attuali siano nel backup
- Controllo coerenza tra dati attuali e backup
- Statistiche dettagliate per tipo e utente
- Tracciamento di appunti mancanti o extra

## Dati Conservati nel Backup

Il backup preserva completamente:
- ✅ **Appunto originale**: Tutti i campi (body, content, attachments via rich_text, stato, team, etc.)
- ✅ **Dati scuola**: Denominazione, comune, provincia, caratteristiche, etc.
- ✅ **Dati adozione**: ISBN, titolo, autori, editore, disciplina, prezzo, etc.
- ✅ **Dati classe**: Anno, sezione, combinazione, tipo grado
- ✅ **Dati libro utente**: Se l'utente ha un libro corrispondente
- ✅ **Timestamp**: Date originali di creazione e modifica
- ✅ **Anno scolastico**: Identificazione del periodo di backup

## Esempio di Utilizzo Completo

```bash
# Scenario: Fine anno scolastico 2024-25, passaggio a 2025-26

# 1. Controllo situazione attuale
rails ssk:stats
# Output: 150 appunti SSK (80 saggi, 50 seguiti, 20 kit)

# 2. Backup dell'anno che finisce
rails ssk:backup[202425]
# Conferma con 's' quando richiesto
# Output: ✅ Backup completato! 150 appunti SSK salvati

# 3. Verifica integrità
rails ssk:verify_backup[202425]
# Output: 🎯 Il backup è completo e aggiornato!

# 4. Eliminazione sicura
rails ssk:delete_after_backup[202425]
# Conferma con 'ELIMINA' quando richiesto
# Output: ✅ Eliminazione completata! 150 appunti SSK eliminati

# 5. Verifica finale
rails ssk:stats
# Output: 0 appunti SSK attuali, 150 nel backup anno 202425
```

## Note Tecniche

### Performance
- Elaborazione in batch (100 record alla volta)
- Includes per ottimizzare le query
- Indici sulla tabella backup per ricerche veloci

### Compatibilità
- Compatibile con Rails 8.0
- Usa transazioni per sicurezza
- Gestione errori robusta

### Manutenzione
- I backup rimangono indefinitamente nella tabella
- Possibile aggiungere pulizia automatica dei backup vecchi
- Esportazione dati per archiviazione esterna

## Recupero Dati

In caso di necessità, i dati possono essere recuperati dalla tabella `ssk_appunti_backup`:

```ruby
# Trova tutti i saggi di un utente per un anno
user = User.find_by(email: 'user@example.com')
saggi_backup = SskAppuntoBackup.saggi
                               .per_utente(user)
                               .per_anno_scolastico('202425')

# Dati completi disponibili
saggi_backup.each do |backup|
  puts "#{backup.titolo} - #{backup.scuola_e_citta}"
  puts "Classe: #{backup.classe_e_sezione}"
  puts "Note: #{backup.body}"
end
```
