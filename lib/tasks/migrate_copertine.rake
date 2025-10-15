namespace :copertine do
  desc "Migra le copertine esistenti dai Libri a EdizioneTitolo per condividerle tra utenti con stesso ISBN"
  task migrate: :environment do
    puts "=== Inizio migrazione copertine a EdizioneTitolo ==="

    migrated_count = 0
    skipped_count = 0
    error_count = 0

    # Trova tutti i libri con copertina allegata
    libri_con_copertina = Libro.includes(:copertina_attachment)
                                .where.not(active_storage_attachments: { id: nil })
                                .joins("INNER JOIN active_storage_attachments ON active_storage_attachments.record_id = libri.id
                                        AND active_storage_attachments.record_type = 'Libro'
                                        AND active_storage_attachments.name = 'copertina'")

    total_libri = libri_con_copertina.count
    puts "Trovati #{total_libri} libri con copertina allegata"

    # Raggruppa per ISBN per trovare il libro "rappresentante" per ogni ISBN
    libri_per_isbn = libri_con_copertina.group_by(&:codice_isbn)

    puts "Trovati #{libri_per_isbn.keys.count} ISBN unici con copertine"
    puts ""

    libri_per_isbn.each do |isbn, libri|
      next if isbn.blank?

      begin
        # Prendi il primo libro con copertina per questo ISBN
        libro_fonte = libri.first

        # Crea o trova l'EdizioneTitolo per questo ISBN
        edizione = EdizioneTitolo.find_or_initialize_by(codice_isbn: isbn)
        edizione.titolo_originale ||= libro_fonte.titolo

        # Se l'edizione ha già una copertina, salta
        if edizione.copertina.attached?
          puts "  ⏭️  ISBN #{isbn}: EdizioneTitolo ha già una copertina"
          skipped_count += 1
          next
        end

        # Copia la copertina dal libro all'edizione
        if libro_fonte.copertina.attached?
          # Usa attach direttamente con il blob esistente (più veloce, non scarica da AWS)
          edizione.copertina.attach(libro_fonte.copertina.blob)
          edizione.save!

          puts "  ✅ ISBN #{isbn}: Copertina migrata (#{libri.count} libri condivideranno questa copertina)"
          migrated_count += 1
        end

      rescue => e
        puts "  ❌ Errore con ISBN #{isbn}: #{e.message}"
        error_count += 1
      end
    end

    puts ""
    puts "=== Migrazione completata ==="
    puts "✅ Copertine migrate: #{migrated_count}"
    puts "⏭️  Copertine saltate: #{skipped_count}"
    puts "❌ Errori: #{error_count}"
    puts ""
    puts "Ora #{EdizioneTitolo.count} EdizioneTitolo hanno copertine condivise tra gli utenti!"
  end

  desc "Verifica quanti libri condivideranno le copertine"
  task stats: :environment do
    puts "=== Statistiche condivisione copertine ==="
    puts ""

    # Conta i libri per ISBN
    isbn_counts = Libro.where.not(codice_isbn: [nil, '']).group(:codice_isbn).count

    # Trova gli ISBN con più di un libro
    isbn_condivisi = isbn_counts.select { |isbn, count| count > 1 }

    puts "📚 Totale libri: #{Libro.count}"
    puts "🔢 ISBN unici: #{isbn_counts.keys.count}"
    puts "🤝 ISBN condivisi tra più utenti: #{isbn_condivisi.count}"
    puts ""

    if isbn_condivisi.any?
      puts "Top 10 ISBN più condivisi:"
      isbn_condivisi.sort_by { |isbn, count| -count }.first(10).each do |isbn, count|
        libro = Libro.find_by(codice_isbn: isbn)
        puts "  • #{isbn} - #{libro&.titolo || 'N/A'}: #{count} copie"
      end
    end

    puts ""

    # Statistiche sulle copertine esistenti
    libri_con_copertina = Libro.joins("INNER JOIN active_storage_attachments ON active_storage_attachments.record_id = libri.id
                                        AND active_storage_attachments.record_type = 'Libro'
                                        AND active_storage_attachments.name = 'copertina'").count

    puts "📸 Libri con copertina: #{libri_con_copertina}"
    puts "📸 EdizioneTitolo con copertina: #{EdizioneTitolo.joins(:copertina_attachment).count}"
  end

  desc "Rimuove le copertine duplicate dai Libri dopo la migrazione (ATTENZIONE: operazione irreversibile)"
  task cleanup: :environment do
    puts "⚠️  ATTENZIONE: Questa operazione rimuoverà le copertine dai singoli Libri"
    puts "Le copertine rimarranno solo su EdizioneTitolo per essere condivise"
    puts ""
    print "Sei sicuro di voler continuare? (scrivi 'SI' per confermare): "

    confirmation = STDIN.gets.chomp

    unless confirmation == 'SI'
      puts "Operazione annullata"
      exit
    end

    removed_count = 0

    Libro.includes(:copertina_attachment).where.not(active_storage_attachments: { id: nil }).find_each do |libro|
      if libro.edizione_titolo&.copertina&.attached?
        libro.copertina.purge
        removed_count += 1
        puts "  🗑️  Rimossa copertina da libro #{libro.id} (#{libro.titolo})"
      end
    end

    puts ""
    puts "✅ Rimosse #{removed_count} copertine duplicate"
    puts "Le copertine sono ora condivise solo tramite EdizioneTitolo"
  end
end
