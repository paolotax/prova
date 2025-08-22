namespace :ssk do
  desc "Backup di tutti gli appunti con adozioni (SSK e non SSK) prima del passaggio anno"
  task :backup, [:anno_scolastico] => :environment do |t, args|
    anno_scolastico = args[:anno_scolastico] || "202425"
    
    puts "🔄 Avvio backup di tutti gli appunti con adozioni per l'anno scolastico #{anno_scolastico}..."
    
    # Conta gli appunti prima del backup
    ssk_count = Appunto.ssk.count
    con_adozioni_count = Appunto.where.not(import_adozione_id: nil).where.not(nome: ['saggio', 'seguito', 'kit']).count
    con_classi_count = Appunto.where.not(classe_id: nil).where(import_adozione_id: nil).count
    totale_count = Appunto.where("import_adozione_id IS NOT NULL OR classe_id IS NOT NULL").count
    
    puts "📊 Trovati #{ssk_count} appunti SSK da salvare nel backup"
    puts "📊 Trovati #{con_adozioni_count} altri appunti con adozioni da salvare nel backup"
    puts "📊 Trovati #{con_classi_count} appunti con classi da salvare nel backup"
    puts "📊 Totale: #{totale_count} appunti da salvare nel backup"
    
    if totale_count == 0
      puts "⚠️  Nessun appunto con adozioni o classi trovato. Backup non necessario."
      exit
    end
    
    # Chiedi conferma
    print "Confermi il backup di #{totale_count} appunti con adozioni/classi? (s/N): "
    response = STDIN.gets.chomp.downcase
    
    unless ['s', 'si', 'y', 'yes'].include?(response)
      puts "❌ Backup annullato dall'utente"
      exit
    end
    
    # Esegui il backup
    begin
      backup_count = SskAppuntoBackup.backup_ssk_appunti!(anno_scolastico)
      puts "✅ Backup completato! #{backup_count} appunti con adozioni salvati nella tabella ssk_appunti_backup"
      
      # Mostra statistiche del backup
      puts "\n📈 Statistiche backup:"
      puts "   - Saggi: #{SskAppuntoBackup.saggi.per_anno_scolastico(anno_scolastico).count}"
      puts "   - Seguiti: #{SskAppuntoBackup.seguiti.per_anno_scolastico(anno_scolastico).count}"
      puts "   - Kit: #{SskAppuntoBackup.kit.per_anno_scolastico(anno_scolastico).count}"
      
      # Altri appunti (non SSK)
      altri_backup = SskAppuntoBackup.per_anno_scolastico(anno_scolastico).where.not(nome: ['saggio', 'seguito', 'kit']).count
      puts "   - Altri appunti: #{altri_backup}"
      
      # Utenti coinvolti
      users_count = SskAppuntoBackup.per_anno_scolastico(anno_scolastico).distinct.count(:user_id)
      puts "   - Utenti coinvolti: #{users_count}"
      
      puts "\n🎯 Il backup è stato completato con successo!"
      puts "💡 Puoi ora procedere con la pulizia usando: rake ssk:delete_after_backup[#{anno_scolastico}]"
      
    rescue => e
      puts "❌ Errore durante il backup: #{e.message}"
      puts e.backtrace.first(5).join("\n")
      exit 1
    end
  end
  
  desc "Modifica gli appunti con adozioni dopo aver verificato il backup (rimuove legame e aggiunge info nel body)"
  task :delete_after_backup, [:anno_scolastico] => :environment do |t, args|
    anno_scolastico = args[:anno_scolastico] || "202425"
    
    puts "🔄 Avvio modifica di tutti gli appunti con adozioni per l'anno scolastico #{anno_scolastico}..."
    
    # Verifica che esistano backup
    backup_count = SskAppuntoBackup.per_anno_scolastico(anno_scolastico).count
    ssk_count = Appunto.ssk.count
    con_adozioni_count = Appunto.where.not(import_adozione_id: nil).where.not(nome: ['saggio', 'seguito', 'kit']).count
    con_classi_count = Appunto.where.not(classe_id: nil).where(import_adozione_id: nil).count
    totale_count = Appunto.where("import_adozione_id IS NOT NULL OR classe_id IS NOT NULL").count
    
    puts "📊 Backup presenti: #{backup_count}"
    puts "📊 Appunti SSK attuali: #{ssk_count}"
    puts "📊 Altri appunti con adozioni attuali: #{con_adozioni_count}"
    puts "📊 Appunti con classi attuali: #{con_classi_count}"
    puts "📊 Totale appunti con adozioni/classi: #{totale_count}"
    
    if backup_count == 0
      puts "❌ Nessun backup trovato per l'anno #{anno_scolastico}. Impossibile procedere con la modifica."
      puts "💡 Esegui prima: rake ssk:backup[#{anno_scolastico}]"
      exit 1
    end
    
    if totale_count == 0
      puts "ℹ️  Nessun appunto con adozioni/classi presente. Modifica non necessaria."
      exit
    end
    
    # Verifica coerenza tra backup e appunti attuali
    backed_up_ids = SskAppuntoBackup.per_anno_scolastico(anno_scolastico).pluck(:original_appunto_id)
    current_appunti_ids = Appunto.where("import_adozione_id IS NOT NULL OR classe_id IS NOT NULL").pluck(:id)
    
    missing_in_backup = current_appunti_ids - backed_up_ids
    if missing_in_backup.any?
      puts "⚠️  ATTENZIONE: #{missing_in_backup.count} appunti con adozioni/classi presenti non sono nel backup!"
      puts "   IDs mancanti: #{missing_in_backup.first(10).join(', ')}#{missing_in_backup.count > 10 ? '...' : ''}"
      puts "💡 Considera di aggiornare il backup prima di procedere."
    end
    
    # Chiedi conferma
    puts "\n⚠️  ATTENZIONE: Questa operazione modificherà #{totale_count} appunti con adozioni/classi!"
    puts "   - #{ssk_count} appunti SSK (saggio, seguito, kit)"
    puts "   - #{con_adozioni_count} altri appunti con adozioni"
    puts "   - #{con_classi_count} appunti con classi"
    puts "📝 Gli appunti verranno scollegati dalle adozioni e le info saranno salvate nel body"
    puts "💾 I dati originali sono stati salvati nel backup per l'anno #{anno_scolastico}"
    print "Confermi la modifica? Scrivi 'MODIFICA' per confermare: "
    response = STDIN.gets.chomp
    
    unless response == 'MODIFICA'
      puts "❌ Modifica annullata. Risposta non corretta."
      exit
    end
    
    # Procedi con la modifica
    begin
      ActiveRecord::Base.transaction do
        # Per sicurezza, modifica solo gli appunti che sono effettivamente nel backup
        appunti_da_modificare = Appunto.includes(:import_adozione, :classe).where("import_adozione_id IS NOT NULL OR classe_id IS NOT NULL").where(id: backed_up_ids)
        modified_count = 0
        
        puts "📝 Modifica di #{appunti_da_modificare.count} appunti con adozioni/classi in corso..."
        
        appunti_da_modificare.find_each do |appunto|
          # Prepara le informazioni da salvare nel body
          info_adozione = []
          
          if appunto.import_adozione
            adozione = appunto.import_adozione
            info_adozione << "#{appunto.nome.upcase} adozione a.s.: #{anno_scolastico}" if appunto.nome.present?
            info_adozione << "Classe: #{adozione.ANNOCORSO} #{adozione.SEZIONEANNO} #{adozione&.COMBINAZIONE&.downcase}" if adozione.ANNOCORSO.present?
            info_adozione << "Titolo: #{adozione.TITOLO}" if adozione.TITOLO.present?
            info_adozione << "Editore: #{adozione.EDITORE}" if adozione.EDITORE.present?
            info_adozione << "ISBN: #{adozione.CODICEISBN}" if adozione.CODICEISBN.present?
          elsif appunto.classe
            classe = appunto.classe
            info_adozione << "appunto a.s.: #{anno_scolastico}" if appunto.classe.present?
            info_adozione << "Classe: #{classe.classe} #{classe.sezione} #{classe.combinazione.downcase}" if classe.classe.present?
          end
          
          # Prepara il nuovo body
          separator = "\n" + "="*50 + "\n"
          info_text = info_adozione.join("\n")
          
          nuovo_body = if appunto.body.present?
            "#{appunto.body}#{separator}\n#{info_text}"
          else
            "#{info_text}"
          end
          
          # Aggiorna l'appunto
          if appunto.is_ssk?
            # Per appunti con adozioni: marca come completato
            appunto.update!(
              import_adozione_id: nil,
              body: nuovo_body,
              completed_at: appunto.created_at,
              stato: 'completato'
            )
          else
            # Per appunti con solo classe_id: non modificare lo stato
            appunto.update!(
              import_adozione_id: nil,
              classe_id: nil,
              body: nuovo_body
            )
          end
          
          modified_count += 1
        end
        
        puts "✅ Modifica completata! #{modified_count} appunti con adozioni/classi modificati"
        puts "📝 I collegamenti alle adozioni/classi sono stati rimossi e le info salvate nel body"
        puts "💾 I dati originali rimangono disponibili nella tabella ssk_appunti_backup"
        
        # Verifica finale
        remaining_ssk = Appunto.ssk.count
        remaining_adozioni = Appunto.where.not(import_adozione_id: nil).where.not(nome: ['saggio', 'seguito', 'kit']).count
        remaining_classi = Appunto.where.not(classe_id: nil).count
        remaining_totale = Appunto.where("import_adozione_id IS NOT NULL OR classe_id IS NOT NULL").count
        
        if remaining_totale > 0
          puts "⚠️  Attenzione: rimangono ancora #{remaining_totale} appunti con adozioni/classi"
          puts "   (#{remaining_ssk} SSK, #{remaining_adozioni} con adozioni, #{remaining_classi} con classi)"
          puts "   (probabilmente non erano nel backup)"
        else
          puts "🎯 Pulizia completata! Nessun appunto con adozioni/classi rimasto."
        end
      end
      
    rescue => e
      puts "❌ Errore durante la modifica: #{e.message}"
      puts e.backtrace.first(5).join("\n")
      exit 1
    end
  end
  
  desc "Mostra statistiche degli appunti con adozioni e dei backup"
  task :stats, [:anno_scolastico] => :environment do |t, args|
    anno_scolastico = args[:anno_scolastico] || "202425"
    
    puts "📊 STATISTICHE APPUNTI CON ADOZIONI"
    puts "=" * 60
    
    # Appunti SSK attuali
    puts "\n🔴 APPUNTI SSK ATTUALI:"
    saggi_count = Appunto.saggi.count
    seguiti_count = Appunto.seguiti.count
    kit_count = Appunto.kit.count
    total_ssk = saggi_count + seguiti_count + kit_count
    
    puts "   - Saggi: #{saggi_count}"
    puts "   - Seguiti: #{seguiti_count}"
    puts "   - Kit: #{kit_count}"
    puts "   - TOTALE SSK: #{total_ssk}"
    
    # Altri appunti con adozioni
    puts "\n🟡 ALTRI APPUNTI CON ADOZIONI:"
    altri_count = Appunto.where.not(import_adozione_id: nil).where.not(nome: ['saggio', 'seguito', 'kit']).count
    totale_count = Appunto.where.not(import_adozione_id: nil).count
    puts "   - Altri appunti: #{altri_count}"
    puts "   - TOTALE CON ADOZIONI: #{totale_count}"
    
    if total_ssk > 0
      puts "\n👥 Appunti SSK per utente:"
      Appunto.ssk.joins(:user).group('users.email').count.each do |email, count|
        puts "   - #{email}: #{count}"
      end
    end
    
    if altri_count > 0
      puts "\n👥 Altri appunti per utente:"
      Appunto.where.not(import_adozione_id: nil).where.not(nome: ['saggio', 'seguito', 'kit']).joins(:user).group('users.email').count.each do |email, count|
        puts "   - #{email}: #{count}"
      end
    end
    
    # Backup per anno scolastico
    puts "\n💾 BACKUP ANNO #{anno_scolastico}:"
    backup_saggi = SskAppuntoBackup.saggi.per_anno_scolastico(anno_scolastico).count
    backup_seguiti = SskAppuntoBackup.seguiti.per_anno_scolastico(anno_scolastico).count
    backup_kit = SskAppuntoBackup.kit.per_anno_scolastico(anno_scolastico).count
    backup_altri = SskAppuntoBackup.per_anno_scolastico(anno_scolastico).where.not(nome: ['saggio', 'seguito', 'kit']).count
    total_backup = SskAppuntoBackup.per_anno_scolastico(anno_scolastico).count
    
    puts "   - Saggi: #{backup_saggi}"
    puts "   - Seguiti: #{backup_seguiti}"
    puts "   - Kit: #{backup_kit}"
    puts "   - Altri appunti: #{backup_altri}"
    puts "   - TOTALE: #{total_backup}"
    
    if total_backup > 0
      puts "\n👥 Per utente nel backup:"
      SskAppuntoBackup.per_anno_scolastico(anno_scolastico).joins(:user).group('users.email').count.each do |email, count|
        puts "   - #{email}: #{count}"
      end
    end
    
    # Tutti i backup disponibili
    puts "\n📅 TUTTI I BACKUP DISPONIBILI:"
    all_backups = SskAppuntoBackup.group(:anno_scolastico_backup).count
    if all_backups.any?
      all_backups.each do |anno, count|
        puts "   - Anno #{anno}: #{count} appunti"
      end
    else
      puts "   - Nessun backup presente"
    end
    
    puts "\n" + "=" * 50
  end
  
  desc "Verifica l'integrità del backup confrontandolo con gli appunti attuali"
  task :verify_backup, [:anno_scolastico] => :environment do |t, args|
    anno_scolastico = args[:anno_scolastico] || "202425"
    
    puts "🔍 VERIFICA INTEGRITÀ BACKUP ANNO #{anno_scolastico}"
    puts "=" * 60
    
    backup_records = SskAppuntoBackup.per_anno_scolastico(anno_scolastico)
    backup_ids = backup_records.pluck(:original_appunto_id)
    current_appunti_ids = Appunto.where.not(import_adozione_id: nil).pluck(:id)
    current_ssk_ids = Appunto.ssk.pluck(:id)
    
    puts "📊 Backup presenti: #{backup_records.count}"
    puts "📊 Appunti con adozioni attuali: #{current_appunti_ids.count}"
    puts "📊 SSK attuali: #{current_ssk_ids.count}"
    
    # Verifica completezza
    missing_in_backup = current_appunti_ids - backup_ids
    extra_in_backup = backup_ids - current_appunti_ids
    
    puts "\n✅ VERIFICA COMPLETEZZA:"
    if missing_in_backup.empty?
      puts "   ✓ Tutti gli appunti con adozioni attuali sono nel backup"
    else
      puts "   ❌ #{missing_in_backup.count} appunti con adozioni mancano nel backup:"
      missing_in_backup.first(10).each do |id|
        appunto = Appunto.find(id)
        puts "     - ID #{id}: #{appunto.nome} (#{appunto.import_adozione&.titolo})"
      end
      puts "     ..." if missing_in_backup.count > 10
    end
    
    puts "\n📋 APPUNTI NEL BACKUP MA NON PIÙ PRESENTI:"
    if extra_in_backup.empty?
      puts "   ✓ Nessun appunto nel backup è stato già eliminato"
    else
      puts "   ℹ️  #{extra_in_backup.count} appunti nel backup sono già stati eliminati"
    end
    
    # Verifica per tipo
    puts "\n📊 DETTAGLIO PER TIPO:"
    ['saggio', 'seguito', 'kit'].each do |tipo|
      backup_tipo = backup_records.where(nome: tipo).count
      current_tipo = Appunto.where(nome: tipo).where.not(import_adozione_id: nil).count
      puts "   - #{tipo.capitalize}: backup=#{backup_tipo}, attuali=#{current_tipo}"
    end
    
    # Altri appunti
    backup_altri = backup_records.where.not(nome: ['saggio', 'seguito', 'kit']).count
    current_altri = Appunto.where.not(import_adozione_id: nil).where.not(nome: ['saggio', 'seguito', 'kit']).count
    puts "   - Altri appunti: backup=#{backup_altri}, attuali=#{current_altri}"
    
    puts "\n" + "=" * 60
    
    if missing_in_backup.empty?
      puts "🎯 Il backup è completo e aggiornato!"
    else
      puts "⚠️  Il backup non è completo. Considera di aggiornarlo."
    end
  end
end
