require 'nokogiri'
require 'open-uri'
require 'net/http'
require 'fileutils'

module Miur
  # Scarica i 4 CSV di anagrafica scuole dal portale MIUR open data e triggera
  # miur:importa_scuole (swap di partizione). Speculare a Miur::AdozioniScraper, ma con
  # 4 dataset fissi invece di ~20 regioni: per ciascun dataset tiene solo l'anno
  # più recente (il filename embedda AAAAAA = anno + AAAAMMGG = data pubblicazione,
  # quindi il massimo lessicografico è il file più nuovo).
  class ScuoleScraper
    DOWNLOAD_DIR = Rails.root.join('tmp', '_miur', 'scuole')
    BASE_URL = 'https://dati.istruzione.it/opendata/opendata/catalogo/elements1'
    USER_AGENT = 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'.freeze
    CATALOG_READ_TIMEOUT = 30
    CSV_OPEN_TIMEOUT = 30
    CSV_READ_TIMEOUT = 1800
    MIN_VALID_SIZE = 1024
    MAX_ATTEMPTS = 3
    RETRY_SLEEP_SECONDS = [10, 30, 60].freeze
    # I 4 dataset di anagrafica: statali, paritarie, prov. autonome statali/paritarie.
    DATASETS = %w[SCUANAGRAFESTAT SCUANAGRAFEPAR SCUANAAUTSTAT SCUANAAUTPAR].freeze
    MIN_CSV_FOR_IMPORT = DATASETS.size

    attr_reader :dataset_aggiornati, :dataset_saltati, :dataset_nuovi, :dataset_falliti, :dataset_stale

    def initialize
      @dataset_aggiornati = []
      @dataset_saltati = []
      @dataset_nuovi = []
      @dataset_falliti = []
      @dataset_stale = []
    end

    def call
      prepare_directory
      scrape_scuole
      process_imports
      notify
    rescue => e
      Rails.logger.error("Errore generale nello scraper scuole MIUR: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
    end

    private

    def prepare_directory
      FileUtils.mkdir_p(DOWNLOAD_DIR)
      FileUtils.chmod(0777, DOWNLOAD_DIR)
    end

    def scrape_scuole
      doc = Nokogiri::HTML(URI.open(
        "#{BASE_URL}/?area=Scuole",
        "User-Agent" => USER_AGENT,
        read_timeout: CATALOG_READ_TIMEOUT
      ))

      latest = latest_filenames(doc)

      DATASETS.each do |dataset|
        filename = latest[dataset]
        if filename.nil?
          Rails.logger.error("[MIUR scuole] #{dataset}: nessun CSV trovato nel catalogo")
          @dataset_falliti << dataset
          next
        end

        csv_url = "#{BASE_URL}/#{filename}"
        filepath = File.join(DOWNLOAD_DIR, filename)
        existing_file, existing_date = find_existing_file(dataset)

        # Il filename embedda anno + data: se è identico al file già a disco, niente da fare.
        if existing_file && File.basename(existing_file) == filename
          @dataset_saltati << dataset
          next
        end

        process_dataset(dataset, csv_url, filepath, existing_file, existing_date)
      end
    end

    # Tra tutti i link .csv della pagina (che elenca anche anni storici e altri
    # dataset) tiene, per ciascuno dei 4 dataset di anagrafica, il filename più recente.
    def latest_filenames(doc)
      latest = {}
      # I link col filename sono <a href="…csv"> senza classe specifica (la classe
      # "csv split" sta su un altro elemento), quindi selezioniamo per estensione href.
      doc.css('a[href$=".csv"]').each do |link|
        href = link['href']
        next if href.blank?

        base = File.basename(href)
        dataset = DATASETS.find { |ds| base.start_with?(ds) }
        next unless dataset

        latest[dataset] = base if latest[dataset].nil? || base > latest[dataset]
      end
      latest
    end

    def process_dataset(dataset, csv_url, filepath, existing_file, existing_date)
      last_error = nil

      MAX_ATTEMPTS.times do |i|
        attempts = i + 1
        Rails.logger.info("[MIUR scuole] #{dataset}: download start (tentativo #{attempts}/#{MAX_ATTEMPTS})")
        started_at = Time.current

        bytes = download_file(csv_url, filepath)

        if bytes < MIN_VALID_SIZE
          File.delete(filepath) if File.exist?(filepath)
          last_error = "bytes < MIN_VALID_SIZE (#{bytes})"
          Rails.logger.warn("[MIUR scuole] #{dataset}: tentativo #{attempts} scaricati solo #{bytes} byte")
          retry_sleep(i) if i < MAX_ATTEMPTS - 1
          next
        end

        if existing_file
          archive_file(existing_file, existing_date)
          @dataset_aggiornati << dataset
        else
          @dataset_nuovi << dataset
        end

        elapsed = (Time.current - started_at).round(1)
        Rails.logger.info("[MIUR scuole] #{dataset}: ok #{bytes} byte in #{elapsed}s (tentativo #{attempts})")
        return
      rescue => e
        File.delete(filepath) if File.exist?(filepath) && File.size(filepath) < MIN_VALID_SIZE
        last_error = "#{e.class}: #{e.message}"
        Rails.logger.error("[MIUR scuole] #{dataset}: tentativo #{attempts} errore — #{last_error}")
        retry_sleep(i) if i < MAX_ATTEMPTS - 1
      end

      Rails.logger.error("[MIUR scuole] #{dataset}: fallita dopo #{MAX_ATTEMPTS} tentativi — ultimo errore: #{last_error}")

      archived = find_archived_csv(dataset)
      if archived
        target = File.join(DOWNLOAD_DIR, File.basename(archived))
        FileUtils.cp(archived, target) unless File.exist?(target)
        Rails.logger.warn("[MIUR scuole] #{dataset}: uso CSV archiviato come fallback (#{File.basename(archived)})")
        @dataset_stale << dataset
      else
        @dataset_falliti << dataset
      end
    end

    def retry_sleep(attempt_index)
      sleep(RETRY_SLEEP_SECONDS.fetch(attempt_index, RETRY_SLEEP_SECONDS.last))
    end

    def find_existing_file(dataset)
      Dir.glob(File.join(DOWNLOAD_DIR, "*.csv")).each do |f|
        next unless File.basename(f).start_with?(dataset)

        if File.size(f) < MIN_VALID_SIZE
          Rails.logger.warn("[MIUR scuole] rimuovo file precedente vuoto: #{File.basename(f)}")
          File.delete(f)
          next
        end

        match = File.basename(f).match(/(\d{8})\.csv/)
        return [f, match && match[1]]
      end
      [nil, nil]
    end

    def find_archived_csv(dataset)
      candidates = Dir.glob(File.join(DOWNLOAD_DIR, "*", "*.csv")).select do |archived|
        File.basename(archived).start_with?(dataset) && File.size(archived) >= MIN_VALID_SIZE
      end
      candidates.max_by { |f| File.basename(f) }
    end

    def archive_file(file, date)
      archive_dir = File.join(DOWNLOAD_DIR, date || "archivio")
      FileUtils.mkdir_p(archive_dir)
      FileUtils.mv(file, File.join(archive_dir, File.basename(file)))
    end

    def download_file(url, path)
      bytes = 0
      URI.open(
        url,
        "User-Agent" => USER_AGENT,
        open_timeout: CSV_OPEN_TIMEOUT,
        read_timeout: CSV_READ_TIMEOUT
      ) do |response|
        File.open(path, 'wb') do |f|
          while (chunk = response.read(64 * 1024))
            f.write(chunk)
            bytes += chunk.bytesize
          end
        end
      end
      bytes
    end

    def process_imports
      if @dataset_aggiornati.empty? && @dataset_nuovi.empty?
        Rails.logger.info "[MIUR scuole] Nessun dataset aggiornato o nuovo, skip import"
        return
      end

      csv_count = Dir.glob(File.join(DOWNLOAD_DIR, "*.csv")).size
      if csv_count < MIN_CSV_FOR_IMPORT
        Rails.logger.error "[MIUR scuole] SKIP IMPORT: solo #{csv_count}/#{MIN_CSV_FOR_IMPORT} CSV presenti. Non eseguo lo swap."
        return
      end

      # Watermark PRIMA dell'invoke: gli esiti dataset vanno agganciati solo al
      # run creato in QUESTO ciclo, mai a un run stale di un giro precedente.
      last_run_id = Miur::ImportRun.scuole.maximum(:id)

      begin
        Rake::Task['miur:importa_scuole'].reenable
        Rake::Task['miur:importa_scuole'].invoke
      rescue Miur::ImportError => e
        Rails.logger.error("[MIUR scuole] import fallito: #{e.message}")
        return
      rescue => e
        # Simmetrico ad AdozioniScraper: logga anche i failure imprevisti
        # invece di lasciarli inghiottire dal rescue generico di call.
        Rails.logger.error("[MIUR scuole] import fallito (errore imprevisto): #{e.class}: #{e.message}")
        Rails.logger.error(e.backtrace.join("\n"))
        return
      end

      attach_esiti_to_run(last_run_id)
    end

    # Le colonne jsonb del run si chiamano regioni_* ma sono liste generiche:
    # qui ci finiscono i dataset di anagrafica.
    def attach_esiti_to_run(last_run_id)
      run = Miur::ImportRun.scuole.where("id > ?", last_run_id || 0).order(:completed_at).last
      run&.update!(
        regioni_aggiornate: @dataset_aggiornati,
        regioni_stale: @dataset_stale,
        regioni_fallite: @dataset_falliti
      )
    end

    def notify
      Rails.logger.info(
        "[MIUR scuole] esito — aggiornati: #{@dataset_aggiornati}, nuovi: #{@dataset_nuovi}, " \
        "saltati: #{@dataset_saltati}, stale: #{@dataset_stale}, falliti: #{@dataset_falliti}"
      )
    end
  end
end
