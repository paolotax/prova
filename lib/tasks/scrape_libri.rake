require 'nokogiri'
require 'open-uri'
require 'net/http'
require 'fileutils'
require 'highline'

namespace :scrape do
  desc "Scarica i file CSV delle adozioni"
  task adozioni: :environment do
    # Crea la directory per i file se non esiste
    download_dir = Rails.root.join('tmp', '_miur', 'adozioni')

    # Crea la directory e imposta i permessi
    puts "Creazione directory e impostazione permessi..."
    puts "Directory da creare: #{download_dir}"
    puts "Directory esiste? #{Dir.exist?(download_dir)}"
    FileUtils.mkdir_p(download_dir)
    puts "Directory creata: #{download_dir}"
    puts "Directory esiste ora? #{Dir.exist?(download_dir)}"
    FileUtils.chmod(0777, download_dir)
    puts "Permessi impostati su 777 per la directory #{download_dir}"

    # URL base del sito
    base_url = 'https://dati.istruzione.it/opendata/opendata/catalogo/elements1'

    # Array per tenere traccia delle regioni
    regioni_aggiornate = []
    regioni_saltate = []
    regioni_nuove = []

    begin
      puts "Inizio download della pagina..."
      # Scarica la pagina
      doc = Nokogiri::HTML(URI.open('https://dati.istruzione.it/opendata/opendata/catalogo/elements1/?area=Adozioni%20libri%20di%20testo'))
      puts "Pagina scaricata con successo"

      # Trova tutte le card
      puts "\nCercando le card dei dataset..."
      cards = doc.css('.card')
      puts "Trovate #{cards.count} card"

      # Hash per tenere traccia dei file già scaricati
      downloaded_files = {}

      cards.each do |card|
        # Trova il link CSV all'interno della card
        csv_link = card.css('a.csv').first
        next unless csv_link

        puts "\nAnalisi card..."

        # Estrai il nome del file dal link
        filename = csv_link['href']
        puts "Nome file: #{filename}"

        # Costruisci l'URL completo
        csv_url = "#{base_url}/#{filename}"

        # Estrai il nome della regione dal titolo e puliscilo
        region = card.css('h3').text.strip
        region = region.gsub('Adozioni libri di testo scolastici. Regione ', '')
        region = region.gsub('.', '')
        puts "Regione: #{region.upcase}"

        # Estrai la data di modifica e puliscila
        data_modifica = card.css('.dettaglio-data').text.strip
        data_modifica = data_modifica.gsub('Modified: ', '')
        puts "Data modifica: #{data_modifica}"

        # Gestione dei duplicati
        if downloaded_files[filename]
          downloaded_files[filename] += 1
          filename = filename.gsub('.csv', "_#{downloaded_files[filename]}.csv")
        else
          downloaded_files[filename] = 1
        end

        filepath = File.join(download_dir, filename)

        # Controlla se il file esiste già
        existing_file = nil
        existing_file_date = nil
        Dir.glob(File.join(download_dir, "*.csv")).each do |f|
          if File.basename(f).start_with?(filename.split('0000').first)
            existing_file = f
            existing_file_date = File.basename(f).match(/(\d{8})\.csv/)&.[](1)
            break
          end
        end

        if existing_file
          puts "File esistente trovato: #{File.basename(existing_file)}"

          if existing_file_date
            # Estrai la data dal div dettaglio-data (formato: 05/06/2025)
            data_modifica_num = data_modifica.match(/(\d{2})\/(\d{2})\/(\d{4})/)
            if data_modifica_num
              data_modifica_formattata = "#{data_modifica_num[3]}#{data_modifica_num[2]}#{data_modifica_num[1]}"
              puts "Confronto date:"
              puts "  - Data file esistente: #{existing_file_date}"
              puts "  - Data modifica: #{data_modifica_formattata}"

              if existing_file_date == data_modifica_formattata
                puts "File già aggiornato, salto il download"
                regioni_saltate << region.upcase
                next
              else
                puts "File da aggiornare, procedo con l'archiviazione e il download"
                regioni_aggiornate << region.upcase

                # Crea la directory di archivio con la data del file vecchio
                archive_dir = File.join(download_dir, existing_file_date)
                FileUtils.mkdir_p(archive_dir)

                # Sposta il file vecchio nella directory di archivio
                archive_path = File.join(archive_dir, File.basename(existing_file))
                FileUtils.mv(existing_file, archive_path)
                puts "File vecchio archiviato in: #{archive_path}"
              end
            end
          end
        else
          regioni_nuove << region.upcase
        end

        puts "Scaricamento #{region}..."
        puts "URL: #{csv_url}"
        puts "Salvataggio come: #{filename}"
        puts "Percorso completo: #{filepath}"

        begin
          # Scarica il file
          puts "Tentativo di download da #{csv_url}..."
          response = URI.open(csv_url)
          puts "Download completato, dimensione: #{response.size} bytes"

          puts "Tentativo di salvataggio in #{filepath}..."
          File.open(filepath, 'wb') do |file|
            content = response.read
            puts "Contenuto letto, dimensione: #{content.size} bytes"
            file.write(content)
            puts "Contenuto scritto nel file"
          end

          # Verifica che il file sia stato effettivamente creato
          if File.exist?(filepath)
            puts "File verificato: #{filepath} (dimensione: #{File.size(filepath)} bytes)"
          else
            puts "ERRORE: Il file non è stato creato in #{filepath}"
          end

          puts "Completato: #{filename}"
        rescue => e
          puts "Errore nel download di #{region}: #{e.message}"
          puts "Backtrace:"
          puts e.backtrace
        end
      end

      puts "\n=== REPORT FINALE ==="
      puts "\nRegioni aggiornate (#{regioni_aggiornate.count}):"
      regioni_aggiornate.each { |r| puts "  - #{r}" }

      puts "\nRegioni saltate (#{regioni_saltate.count}):"
      regioni_saltate.each { |r| puts "  - #{r}" }

      puts "\nRegioni nuove (#{regioni_nuove.count}):"
      regioni_nuove.each { |r| puts "  - #{r}" }

      puts "\nDownload completato! I file sono stati salvati in: #{download_dir}"
      Rake::Task['import:splitta_adozioni'].invoke
      Rake::Task['import:new_adozioni'].invoke("true")
      Rake::Task['import:cambia_religione'].invoke
      Rake::Task['scrape:delete_adozioni'].invoke("true")

    rescue => e
      puts "Si è verificato un errore generale: #{e.message}"
      puts e.backtrace
    end
  end

  desc "Elimina i file CSV nella directory tmp/_miur/adozioni"
  task :delete_adozioni, [:force] => :environment do |t, args|
    include ActionView::Helpers
    include ApplicationHelper

    # Define the directory path
    adozioni_dir = Rails.root.join('tmp', '_miur', 'adozioni')

    # Check if directory exists
    unless Dir.exist?(adozioni_dir)
      puts "Directory #{adozioni_dir} non esiste"
      exit 1
    end

    # Get list of files
    files = Dir.glob(File.join(adozioni_dir, '*.csv'))

    if files.empty?
      puts "Nessun file CSV trovato in #{adozioni_dir}"
      exit 0
    end

    # Log files to be deleted
    puts "Trovati #{files.count} file da eliminare:"
    files.each do |file|
      puts "  - #{File.basename(file)}"
    end

    # Ask for confirmation using HighLine
    answer = args[:force] == 'true' ? true : HighLine.agree("Vuoi eliminare questi file? (y/n)")

    if answer == true
      # Delete files
      files.each do |file|
        begin
          FileUtils.rm(file)
          puts "Eliminato: #{File.basename(file)}"
        rescue => e
          puts "Errore nell'eliminazione di #{File.basename(file)}: #{e.message}"
        end
      end
      puts "Eliminazione completata"
    else
      puts "Operazione annullata dall'utente"
    end
  end

  desc "Rimuove i file CSV da Git e dal filesystem"
  task remove_from_git: :environment do
    include ActionView::Helpers
    include ApplicationHelper

    # Define the directory path
    adozioni_dir = Rails.root.join('tmp', '_miur', 'adozioni')

    # Check if directory exists
    unless Dir.exist?(adozioni_dir)
      puts "Directory #{adozioni_dir} non esiste"
      exit 1
    end

    # Get list of files
    files = Dir.glob(File.join(adozioni_dir, '*.csv'))

    if files.empty?
      puts "Nessun file CSV trovato in #{adozioni_dir}"
      exit 0
    end

    # Log files to be removed
    puts "Trovati #{files.count} file da rimuovere da Git:"
    files.each do |file|
      puts "  - #{File.basename(file)}"
    end

    # Ask for confirmation using HighLine
    answer = HighLine.agree("Vuoi rimuovere questi file da Git e dal filesystem? (y/n)")

    if answer == true
      # Remove files from Git and filesystem
      files.each do |file|
        begin
          # Remove from Git
          system("git rm --cached #{file}")
          if $?.success?
            puts "Rimosso da Git: #{File.basename(file)}"
          else
            puts "Errore nella rimozione da Git di #{File.basename(file)}"
          end

          # Remove from filesystem
          FileUtils.rm(file)
          puts "Eliminato dal filesystem: #{File.basename(file)}"
        rescue => e
          puts "Errore nella rimozione di #{File.basename(file)}: #{e.message}"
        end
      end

      # Update .gitignore if needed
      gitignore_path = Rails.root.join('.gitignore')
      gitignore_content = File.read(gitignore_path)
      unless gitignore_content.include?('tmp/_miur/adozioni/*.csv')
        File.open(gitignore_path, 'a') do |f|
          f.puts "\n# Ignore MIUR adoption files"
          f.puts 'tmp/_miur/adozioni/*.csv'
        end
        puts "\nAggiunto tmp/_miur/adozioni/*.csv a .gitignore"
      end

      puts "\nRimozione completata. Ricordati di committare le modifiche con:"
      puts "git add .gitignore"
      puts "git commit -m 'Remove MIUR adoption files from Git'"
    else
      puts "Operazione annullata dall'utente"
    end
  end
end