namespace :cache do
  desc "Pulisce la cache delle statistiche homepage"
  task clear_stats: :environment do
    puts "Cancellazione cache statistiche homepage..."
    
    # Lista delle chiavi da cancellare
    keys = [
      "stats/totale_scuole",
      "stats/old_totale_scuole", 
      "stats/totale_adozioni",
      "stats/old_totale_adozioni"
    ]
    
    keys.each do |key|
      if Rails.cache.delete(key)
        puts "✓ Cancellata: #{key}"
      else
        puts "⚠ Non trovata: #{key}"
      end
    end
    
    puts "✅ Cache statistiche pulita completamente!"
  end

  desc "Pulisce tutta la cache con pattern stats/*"
  task clear_all_stats: :environment do
    puts "Cancellazione di tutta la cache stats/*..."
    
    deleted_count = Rails.cache.delete_matched("stats/*")
    puts "✅ Cancellate #{deleted_count} voci dalla cache!"
  end

  desc "Mostra lo stato della cache delle statistiche"
  task show_stats: :environment do
    puts "Stato cache statistiche homepage:"
    puts "=" * 40
    
    keys = [
      "stats/totale_scuole",
      "stats/old_totale_scuole", 
      "stats/totale_adozioni",
      "stats/old_totale_adozioni"
    ]
    
    keys.each do |key|
      value = Rails.cache.read(key)
      if value
        puts "✓ #{key}: #{value}"
      else
        puts "✗ #{key}: NON PRESENTE"
      end
    end
  end

  desc "Forza il ricalcolo delle statistiche homepage"
  task recalculate_stats: :environment do
    puts "Ricalcolo statistiche homepage..."
    
    # Prima cancella la cache
    Rake::Task["cache:clear_stats"].invoke
    
    puts "\nRicalcolo in corso..."
    
    # Poi ricalcola forzando l'esecuzione
    totale_scuole = ImportAdozione.distinct.count(:CODICESCUOLA)
    old_totale_scuole = OldAdozione.distinct.count(:codicescuola)
    totale_adozioni = ImportAdozione.count
    old_totale_adozioni = OldAdozione.count
    
    # Salva in cache
    Rails.cache.write("stats/totale_scuole", totale_scuole, expires_in: 1.month)
    Rails.cache.write("stats/old_totale_scuole", old_totale_scuole, expires_in: 1.month)
    Rails.cache.write("stats/totale_adozioni", totale_adozioni, expires_in: 1.month)
    Rails.cache.write("stats/old_totale_adozioni", old_totale_adozioni, expires_in: 1.month)
    
    puts "✅ Statistiche ricalcolate e salvate in cache!"
    puts "   Scuole 2025: #{totale_scuole}"
    puts "   Scuole 2024: #{old_totale_scuole}"
    puts "   Adozioni 2025: #{totale_adozioni}"
    puts "   Adozioni 2024: #{old_totale_adozioni}"
  end
end
