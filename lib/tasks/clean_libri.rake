namespace :libri do
  desc "Rimuove 'aa.vv.' e 'AA.VV.' dall'inizio dei titoli di tutti i libri"
  task clean_aavv: :environment do
    puts "=== PULIZIA TITOLI DA AA.VV. ==="
    puts ""

    # Trova tutti i libri che iniziano con aa.vv. o AA.VV.
    libri = Libro.where("titolo ILIKE ? OR titolo ILIKE ? OR titolo ILIKE ?", "aa.vv.%", "AA.VV.%", "AA VV%")

    total = libri.count
    puts "Trovati #{total} libri con titolo che inizia con aa.vv. o AA.VV."
    puts ""

    if total == 0
      puts "Nessun libro da aggiornare"
      exit
    end

    # Mostra esempi prima della modifica
    puts "Esempi di titoli da modificare:"
    libri.limit(5).each do |libro|
      puts "  #{libro.id}: #{libro.titolo}"
    end
    puts ""

    print "Vuoi procedere con la pulizia? (scrivi 'SI' per confermare): "
    confirmation = STDIN.gets.chomp

    unless confirmation == 'SI'
      puts "Operazione annullata"
      exit
    end

    puts ""
    updated = 0
    errors = 0

    libri.find_each do |libro|
      old_title = libro.titolo

      # Rimuove aa.vv. e AA.VV. dall'inizio (case insensitive) e pulisce gli spazi
      new_title = libro.titolo
                       .sub(/^aa\.vv\.\s*/i, '')  # Rimuove solo dall'inizio con eventuali spazi dopo
                       .strip                      # Rimuove spazi all'inizio e alla fine

      if new_title != old_title
        libro.titolo = new_title

        if libro.save
          puts "  ✅ #{libro.id}: #{old_title} → #{new_title}"
          updated += 1
        else
          puts "  ❌ Errore #{libro.id}: #{libro.errors.full_messages.join(', ')}"
          errors += 1
        end
      end
    end

    puts ""
    puts "=== RISULTATI ==="
    puts "✅ Titoli aggiornati: #{updated}"
    puts "❌ Errori: #{errors}"
  end

  desc "Preview dei titoli con aa.vv. che verranno modificati"
  task preview_clean_aavv: :environment do
    puts "=== PREVIEW PULIZIA TITOLI DA AA.VV. ==="
    puts ""

    libri = Libro.where("titolo ILIKE ? OR titolo ILIKE ?", "aa.vv.%", "AA.VV.%")

    puts "Trovati #{libri.count} libri con titolo che inizia con aa.vv. o AA.VV."
    puts ""

    if libri.count == 0
      puts "Nessun libro da aggiornare"
      exit
    end

    puts "PRIMA → DOPO:"
    puts ""

    libri.each do |libro|
      old_title = libro.titolo
      new_title = libro.titolo
                       .sub(/^aa\.vv\.\s*/i, '')
                       .strip

      puts "#{libro.id}: #{old_title}"
      puts "     → #{new_title}"
      puts ""
    end

    puts ""
    puts "Per eseguire la pulizia, lancia:"
    puts "  rails libri:clean_aavv"
  end
end
