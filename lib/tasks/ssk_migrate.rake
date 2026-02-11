namespace :ssk do
  desc "Migra appunti SSK nella tabella consegne_saggio"
  task migrate: :environment do
    puts "Avvio migrazione SSK -> consegne_saggio..."

    appunti_ssk = Appunto.where(nome: %w[saggio seguito kit]).where.not(import_adozione_id: nil)
    total = appunti_ssk.count
    migrated = 0
    skipped = 0
    errors = []

    puts "Trovati #{total} appunti SSK con import_adozione_id"
    puts "  Saggi: #{appunti_ssk.where(nome: 'saggio').count}"
    puts "  Kit: #{appunti_ssk.where(nome: 'kit').count}"
    puts "  Seguiti: #{appunti_ssk.where(nome: 'seguito').count}"

    # Senza import_adozione_id
    senza = Appunto.where(nome: %w[saggio seguito kit]).where(import_adozione_id: nil).count
    puts "  Senza import_adozione_id (saltati): #{senza}" if senza > 0

    # Cache categorie kit e libri kit per user
    kit_categorie = {}
    kit_libri = {}

    appunti_ssk.find_each do |appunto|
      # Trova import_adozione direttamente (associazione commentata)
      import_adozione = ImportAdozione.find_by(id: appunto.import_adozione_id)
      unless import_adozione
        errors << "Appunto #{appunto.id}: import_adozione #{appunto.import_adozione_id} non trovata"
        skipped += 1
        next
      end

      # Trova la Classe account-scoped
      classe = Classe.find_by(
        account_id: appunto.account_id,
        codice_ministeriale_origine: import_adozione.CODICESCUOLA,
        classe_origine: import_adozione.ANNOCORSO,
        sezione_origine: import_adozione.SEZIONEANNO
      )

      unless classe
        errors << "Appunto #{appunto.id} (#{appunto.nome}): Classe non trovata per #{import_adozione.CODICESCUOLA}/#{import_adozione.ANNOCORSO}/#{import_adozione.SEZIONEANNO}"
        skipped += 1
        next
      end

      # Trova l'Adozione
      adozione = Adozione.find_by(
        classe_id: classe.id,
        codice_isbn: import_adozione.CODICEISBN,
        account_id: appunto.account_id
      )

      unless adozione
        errors << "Appunto #{appunto.id} (#{appunto.nome}): Adozione non trovata per classe #{classe.nome_breve} isbn #{import_adozione.CODICEISBN}"
        skipped += 1
        next
      end

      # Determina libro_id e note in base al tipo
      libro_id = nil
      note = appunto.body

      case appunto.nome
      when "saggio"
        libro_id = adozione.libro_id
      when "kit"
        libro_id = find_or_create_kit_libro(
          appunto.user, appunto.account_id,
          import_adozione, kit_categorie, kit_libri
        )
      when "seguito"
        libro_id = nil
      end

      ConsegnaSaggio.create!(
        account_id: appunto.account_id,
        user_id: appunto.user_id,
        adozione_id: adozione.id,
        tipo: appunto.nome,
        libro_id: libro_id,
        quantita: 1,
        note: note
      )
      migrated += 1

      print "\r  #{migrated}/#{total} migrati, #{skipped} saltati"
    rescue => e
      errors << "Appunto #{appunto.id}: #{e.message}"
      skipped += 1
    end

    puts "\n\nMigrazione completata:"
    puts "  Migrati: #{migrated}"
    puts "  Saltati: #{skipped}"
    puts "  ConsegneSaggio totali: #{ConsegnaSaggio.count}"

    if errors.any?
      puts "\nErrori (#{errors.size}):"
      errors.first(50).each { |e| puts "  - #{e}" }
      puts "  ... e altri #{errors.size - 50}" if errors.size > 50
    end
  end

  desc "Mostra statistiche pre-migrazione SSK"
  task migrate_preview: :environment do
    total_ssk = Appunto.where(nome: %w[saggio seguito kit]).count
    con_ia = Appunto.where(nome: %w[saggio seguito kit]).where.not(import_adozione_id: nil).count
    senza_ia = Appunto.where(nome: %w[saggio seguito kit]).where(import_adozione_id: nil).count

    puts "Appunti SSK totali: #{total_ssk}"
    puts "  Saggi: #{Appunto.where(nome: 'saggio').count}"
    puts "  Kit: #{Appunto.where(nome: 'kit').count}"
    puts "  Seguiti: #{Appunto.where(nome: 'seguito').count}"
    puts ""
    puts "Con import_adozione_id: #{con_ia}"
    puts "Senza import_adozione_id: #{senza_ia}"

    # Verifica quanti hanno un'adozione corrispondente
    matchable = 0
    no_classe = 0
    no_adozione = 0
    no_import = 0

    Appunto.where(nome: %w[saggio seguito kit]).where.not(import_adozione_id: nil).find_each do |appunto|
      ia = ImportAdozione.find_by(id: appunto.import_adozione_id)
      unless ia
        no_import += 1
        next
      end

      classe = Classe.find_by(
        account_id: appunto.account_id,
        codice_ministeriale_origine: ia.CODICESCUOLA,
        classe_origine: ia.ANNOCORSO,
        sezione_origine: ia.SEZIONEANNO
      )
      unless classe
        no_classe += 1
        next
      end

      adozione = Adozione.find_by(
        classe_id: classe.id,
        codice_isbn: ia.CODICEISBN,
        account_id: appunto.account_id
      )

      if adozione
        matchable += 1
      else
        no_adozione += 1
      end
    end

    puts ""
    puts "Migrabili: #{matchable}"
    puts "Import_adozione non trovata: #{no_import}"
    puts "Classe non trovata: #{no_classe}"
    puts "Adozione non trovata: #{no_adozione}"
    puts "Totale non migrabili: #{no_import + no_classe + no_adozione}"
  end
end

def find_or_create_kit_libro(user, account_id, import_adozione, kit_categorie, kit_libri)
  # Trova o crea categoria "kit" per questo user
  categoria = kit_categorie[user.id] ||= Categoria.find_or_create_by!(
    user_id: user.id,
    account_id: account_id,
    nome_categoria: "kit"
  )

  disciplina = import_adozione.DISCIPLINA || "VARIE"
  anno_corso = import_adozione.ANNOCORSO || "0"
  codice_isbn = "KIT-#{disciplina.parameterize}-#{anno_corso}-#{user.id}"

  kit_libri[codice_isbn] ||= Libro.find_or_create_by!(
    user_id: user.id,
    account_id: account_id,
    codice_isbn: codice_isbn
  ) do |libro|
    libro.titolo = "KIT 2025 #{disciplina} #{anno_corso}"
    libro.categoria = categoria
    libro.prezzo_in_cents = 0
  end

  kit_libri[codice_isbn].id
end
