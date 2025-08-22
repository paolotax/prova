require 'benchmark'

namespace :db_update do
  desc "Aggiorna database con nuove scuole e adozioni 2025"
  task :scuole_e_adozioni, [:force] => :environment do |t, args|
    
    Rails.logger.info "Inizio aggiornamento database con nuove scuole e adozioni 2025"
    
    # Conferma dall'utente per sicurezza
    if args[:force] != 'true'
      require 'highline'
      answer = HighLine.agree("Vuoi procedere con l'aggiornamento del database? Questo aggiornerà scuole e adozioni. (y/n)")
      unless answer
        puts "Operazione annullata dall'utente"
        exit
      end
    end

    total_benchmark = Benchmark.realtime do
      
      # FASE 1: Aggiornamento scuole
      puts "\n=== FASE 1: Aggiornamento import_scuole con dati da new_scuole ==="
      
      aggiorna_scuole_time = Benchmark.realtime do
        
        # Legge il contenuto del primo script SQL
        sql_scuole_path = Rails.root.join('_sql', '2025_01_aggiorna_scuole.sql')
        unless File.exist?(sql_scuole_path)
          raise "File non trovato: #{sql_scuole_path}"
        end
        
        sql_scuole_content = File.read(sql_scuole_path)
        
        puts "Eseguendo script aggiornamento scuole..."
        
        begin
          # Esegue l'intero script come transazione unica
          ActiveRecord::Base.connection.execute(sql_scuole_content)
          puts "✅ Script scuole eseguito con successo"
          
          # Verifica risultati
          puts "\nVerifica risultati:"
          
          # Conta totale scuole
          total_scuole = ActiveRecord::Base.connection.execute(
            "SELECT COUNT(*) as count FROM import_scuole"
          ).first['count']
          puts "  📊 Totale scuole in import_scuole: #{total_scuole.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1.').reverse}"
          
          # Conta scuole aggiornate di recente (ultimo minuto)
          recent_updates = ActiveRecord::Base.connection.execute(
            "SELECT COUNT(*) as count FROM import_scuole WHERE updated_at >= NOW() - INTERVAL '1 minute'"
          ).first['count']
          puts "  🔄 Scuole aggiornate negli ultimi 60 secondi: #{recent_updates.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1.').reverse}"
          
        rescue => e
          Rails.logger.error "Errore nell'esecuzione dello script scuole: #{e.message}"
          puts "❌ ERRORE nello script scuole: #{e.message}"
          raise e
        end
      end
      
      puts "✅ Aggiornamento scuole completato in #{aggiorna_scuole_time.round(2)} secondi"
      
      # FASE 2: Gestione adozioni (trasferimento tra tabelle)
      puts "\n=== FASE 2: Trasferimento adozioni tra tabelle ==="
      
      gestione_adozioni_time = Benchmark.realtime do
        
        # Legge il contenuto del secondo script SQL
        sql_adozioni_path = Rails.root.join('_sql', '2025_02_scorri_adozioni .sql')
        unless File.exist?(sql_adozioni_path)
          raise "File non trovato: #{sql_adozioni_path}"
        end
        
        sql_adozioni_content = File.read(sql_adozioni_path)
        
        # Esegue l'intero script come transazione singola
        begin
          ActiveRecord::Base.connection.execute(sql_adozioni_content)
          puts "✅ Script adozioni eseguito con successo"
        rescue => e
          Rails.logger.error "Errore nell'esecuzione dello script adozioni: #{e.message}"
          puts "ERRORE nello script adozioni: #{e.message}"
          raise e
        end
      end
      
      puts "✅ Gestione adozioni completata in #{gestione_adozioni_time.round(2)} secondi"
      
      # FASE 3: Verifiche finali
      puts "\n=== FASE 3: Verifiche finali ==="
      
      verifiche_time = Benchmark.realtime do
        
        # Conta record nelle tabelle principali
        puts "\nConteggio record nelle tabelle:"
        
        tabelle_da_verificare = [
          'import_scuole',
          'old_adozioni', 
          'import_adozioni',
          'new_adozioni',
          'new_scuole'
        ]
        
        tabelle_da_verificare.each do |tabella|
          begin
            count = ActiveRecord::Base.connection.execute("SELECT COUNT(*) as count FROM #{tabella}").first['count']
            puts "  #{tabella}: #{count.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1.').reverse} record"
          rescue => e
            puts "  #{tabella}: Errore nel conteggio (#{e.message})"
          end
        end
        
        # Verifica scuole con import_scuola_id
        begin
          matched_schools = ActiveRecord::Base.connection.execute(
            "SELECT COUNT(*) as count FROM old_adozioni WHERE import_scuola_id IS NOT NULL"
          ).first['count']
          
          total_old_adozioni = ActiveRecord::Base.connection.execute(
            "SELECT COUNT(*) as count FROM old_adozioni"
          ).first['count']
          
          if total_old_adozioni > 0
            percentage = (matched_schools.to_f / total_old_adozioni * 100).round(2)
            puts "\nCopertura scuole nelle adozioni:"
            puts "  Adozioni con scuola collegata: #{matched_schools.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1.').reverse} (#{percentage}%)"
            puts "  Adozioni senza scuola: #{(total_old_adozioni - matched_schools).to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1.').reverse}"
          end
        rescue => e
          puts "Errore nella verifica copertura scuole: #{e.message}"
        end
      end
      
      puts "✅ Verifiche completate in #{verifiche_time.round(2)} secondi"
      
      # FASE 4: Ricostruzione viste materializzate
      puts "\n=== FASE 4: Ricostruzione viste materializzate ==="
      
      refresh_views_time = Benchmark.realtime do
        begin
          puts "Ricostruendo vista materializzata view_classi..."
          Scenic.database.refresh_materialized_view('view_classi', concurrently: false, cascade: false)
          puts "✅ Vista view_classi aggiornata con successo"
        rescue => e
          Rails.logger.error "Errore nella ricostruzione delle viste: #{e.message}"
          puts "❌ ERRORE nella ricostruzione viste: #{e.message}"
          raise e
        end
      end
      
      puts "✅ Ricostruzione viste completata in #{refresh_views_time.round(2)} secondi"
    end
    
    puts "\n🎉 AGGIORNAMENTO COMPLETATO in #{total_benchmark.round(2)} secondi totali"
    Rails.logger.info "Aggiornamento database completato con successo in #{total_benchmark.round(2)} secondi"
  end

  desc "Solo aggiornamento scuole da new_scuole"
  task :solo_scuole => :environment do
    
    Rails.logger.info "Inizio aggiornamento solo scuole"
    
    puts "=== Aggiornamento import_scuole con dati da new_scuole ==="
    
    benchmark_time = Benchmark.realtime do
      sql_path = Rails.root.join('_sql', '2025_01_aggiorna_scuole.sql')
      unless File.exist?(sql_path)
        raise "File non trovato: #{sql_path}"
      end
      
      sql_content = File.read(sql_path)
      
      puts "Eseguendo script aggiornamento scuole..."
      
      begin
        # Esegue l'intero script come transazione unica
        ActiveRecord::Base.connection.execute(sql_content)
        puts "✅ Script scuole eseguito con successo"
        
        # Verifica risultati
        puts "\nVerifica risultati:"
        
        # Conta totale scuole
        total_scuole = ActiveRecord::Base.connection.execute(
          "SELECT COUNT(*) as count FROM import_scuole"
        ).first['count']
        puts "  📊 Totale scuole in import_scuole: #{total_scuole.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1.').reverse}"
        
        # Conta scuole aggiornate di recente (ultimo minuto)
        recent_updates = ActiveRecord::Base.connection.execute(
          "SELECT COUNT(*) as count FROM import_scuole WHERE updated_at >= NOW() - INTERVAL '1 minute'"
        ).first['count']
        puts "  🔄 Scuole aggiornate negli ultimi 60 secondi: #{recent_updates.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1.').reverse}"
        
      rescue => e
        Rails.logger.error "Errore nell'esecuzione dello script scuole: #{e.message}"
        puts "❌ ERRORE nello script scuole: #{e.message}"
        raise e
      end
    end
    
    puts "✅ Aggiornamento scuole completato in #{benchmark_time.round(2)} secondi"
    Rails.logger.info "Aggiornamento scuole completato con successo"
  end

  desc "Solo gestione adozioni (trasferimento tra tabelle)"
  task :solo_adozioni => :environment do
    
    Rails.logger.info "Inizio gestione adozioni"
    
    puts "=== Trasferimento adozioni tra tabelle ==="
    
    benchmark_time = Benchmark.realtime do
      sql_path = Rails.root.join('_sql', '2025_02_scorri_adozioni .sql')
      unless File.exist?(sql_path)
        raise "File non trovato: #{sql_path}"
      end
      
      sql_content = File.read(sql_path)
      
      begin
        ActiveRecord::Base.connection.execute(sql_content)
        puts "✅ Script adozioni eseguito con successo"
      rescue => e
        Rails.logger.error "Errore nell'esecuzione dello script adozioni: #{e.message}"
        raise e
      end
    end
    
    puts "✅ Gestione adozioni completata in #{benchmark_time.round(2)} secondi"
    Rails.logger.info "Gestione adozioni completata con successo"
  end

  desc "Verifica stato database dopo aggiornamento"
  task :verifica => :environment do
    
    puts "=== Verifica stato database ==="
    
    tabelle_da_verificare = [
      'import_scuole',
      'old_adozioni', 
      'import_adozioni',
      'new_adozioni',
      'new_scuole'
    ]
    
    puts "\nConteggio record nelle tabelle:"
    tabelle_da_verificare.each do |tabella|
      begin
        count = ActiveRecord::Base.connection.execute("SELECT COUNT(*) as count FROM #{tabella}").first['count']
        puts "  #{tabella}: #{count.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1.').reverse} record"
      rescue => e
        puts "  #{tabella}: Errore nel conteggio (#{e.message})"
      end
    end
    
    # Verifica copertura scuole nelle adozioni
    begin
      matched_schools = ActiveRecord::Base.connection.execute(
        "SELECT COUNT(*) as count FROM old_adozioni WHERE import_scuola_id IS NOT NULL"
      ).first['count']
      
      total_old_adozioni = ActiveRecord::Base.connection.execute(
        "SELECT COUNT(*) as count FROM old_adozioni"
      ).first['count']
      
      if total_old_adozioni > 0
        percentage = (matched_schools.to_f / total_old_adozioni * 100).round(2)
        puts "\nCopertura scuole nelle adozioni:"
        puts "  Adozioni con scuola collegata: #{matched_schools.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1.').reverse} (#{percentage}%)"
        puts "  Adozioni senza scuola: #{(total_old_adozioni - matched_schools).to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1.').reverse}"
      end
    rescue => e
      puts "Errore nella verifica copertura scuole: #{e.message}"
    end
  end

  desc "Ricostruzione viste materializzate"
  task :refresh_views => :environment do
    
    Rails.logger.info "Inizio ricostruzione viste materializzate"
    
    puts "=== Ricostruzione viste materializzate ==="
    
    benchmark_time = Benchmark.realtime do
      begin
        puts "Ricostruendo vista materializzata view_classi..."
        Scenic.database.refresh_materialized_view('view_classi', concurrently: false, cascade: false)
        puts "✅ Vista view_classi aggiornata con successo"
        
        # Verifica del contenuto della vista
        classi_count = ActiveRecord::Base.connection.execute(
          "SELECT COUNT(*) as count FROM view_classi"
        ).first['count']
        puts "  📊 Classi nella vista: #{classi_count.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1.').reverse}"
        
      rescue => e
        Rails.logger.error "Errore nella ricostruzione delle viste: #{e.message}"
        puts "❌ ERRORE nella ricostruzione viste: #{e.message}"
        raise e
      end
    end
    
    puts "✅ Ricostruzione viste completata in #{benchmark_time.round(2)} secondi"
    Rails.logger.info "Ricostruzione viste completata con successo"
  end
end
