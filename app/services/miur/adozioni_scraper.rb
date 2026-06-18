require 'nokogiri'
require 'open-uri'
require 'net/http'
require 'fileutils'

module Miur
  class AdozioniScraper
    DOWNLOAD_DIR = Rails.root.join('tmp', '_miur', 'adozioni')
    BASE_URL = 'https://dati.istruzione.it/opendata/opendata/catalogo/elements1'
    USER_AGENT = 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'.freeze
    CATALOG_READ_TIMEOUT = 30
    CSV_OPEN_TIMEOUT = 30
    CSV_READ_TIMEOUT = 1800
    MIN_VALID_SIZE = 1024
    MAX_ATTEMPTS = 3
    RETRY_SLEEP_SECONDS = [10, 30, 60].freeze
    MIN_CSV_FOR_IMPORT = 18

    attr_reader :regioni_aggiornate, :regioni_saltate, :regioni_nuove, :regioni_fallite, :regioni_stale

    def initialize
      @regioni_aggiornate = []
      @regioni_saltate = []
      @regioni_nuove = []
      @regioni_fallite = []
      @regioni_stale = []
    end

    def call
      prepare_directory
      scrape_adozioni
      process_imports
      notify
    rescue => e
      Rails.logger.error("Errore generale nello scraper MIUR: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
    end

    private

    def prepare_directory
      FileUtils.mkdir_p(DOWNLOAD_DIR)
      FileUtils.chmod(0777, DOWNLOAD_DIR)
    end

    def scrape_adozioni
      doc = Nokogiri::HTML(URI.open(
        "#{BASE_URL}/?area=Adozioni%20libri%20di%20testo",
        "User-Agent" => USER_AGENT,
        read_timeout: CATALOG_READ_TIMEOUT
      ))
      cards = doc.css('.card')

      cards.each do |card|
        next unless (csv_link = card.css('a.csv').first)

        filename = csv_link['href']
        csv_url = "#{BASE_URL}/#{filename}"

        region = clean_region_name(card.css('h3').text.strip)
        data_modifica = parse_data(card.css('.dettaglio-data').text.strip)

        filepath = File.join(DOWNLOAD_DIR, filename)
        existing_file, existing_date = find_existing_file(filename)

        if existing_file && existing_date == data_modifica
          @regioni_saltate << region
          next
        end

        process_region(region, csv_url, filepath, existing_file, existing_date)
      end
    end

    def process_region(region, csv_url, filepath, existing_file, existing_date)
      attempts = 0
      last_error = nil

      MAX_ATTEMPTS.times do |i|
        attempts = i + 1
        Rails.logger.info("[MIUR] #{region}: download start (tentativo #{attempts}/#{MAX_ATTEMPTS})")
        started_at = Time.current

        bytes = download_file(csv_url, filepath)

        if bytes < MIN_VALID_SIZE
          File.delete(filepath) if File.exist?(filepath)
          last_error = "bytes < MIN_VALID_SIZE (#{bytes})"
          Rails.logger.warn("[MIUR] #{region}: tentativo #{attempts} scaricati solo #{bytes} byte")
          retry_sleep(i) if i < MAX_ATTEMPTS - 1
          next
        end

        if existing_file
          archive_file(existing_file, existing_date)
          @regioni_aggiornate << region
        else
          @regioni_nuove << region
        end

        elapsed = (Time.current - started_at).round(1)
        Rails.logger.info("[MIUR] #{region}: ok #{bytes} byte in #{elapsed}s (tentativo #{attempts})")
        return
      rescue => e
        File.delete(filepath) if File.exist?(filepath) && File.size(filepath) < MIN_VALID_SIZE
        last_error = "#{e.class}: #{e.message}"
        Rails.logger.error("[MIUR] #{region}: tentativo #{attempts} errore — #{last_error}")
        retry_sleep(i) if i < MAX_ATTEMPTS - 1
      end

      Rails.logger.error("[MIUR] #{region}: fallita dopo #{MAX_ATTEMPTS} tentativi — ultimo errore: #{last_error}")

      filename = File.basename(filepath)
      archived = find_archived_csv(filename)
      if archived
        target = File.join(DOWNLOAD_DIR, File.basename(archived))
        FileUtils.cp(archived, target) unless File.exist?(target)
        Rails.logger.warn("[MIUR] #{region}: uso CSV archiviato come fallback (#{File.basename(archived)})")
        @regioni_stale << region
      else
        @regioni_fallite << region
      end
    end

    def retry_sleep(attempt_index)
      sleep(RETRY_SLEEP_SECONDS.fetch(attempt_index, RETRY_SLEEP_SECONDS.last))
    end

    def clean_region_name(text)
      text.gsub('Adozioni libri di testo scolastici. Regione ', '').gsub('.', '').upcase
    end

    def parse_data(raw_data)
      raw_data.gsub('Modified: ', '').split('/').reverse.join
    end

    def find_existing_file(filename)
      Dir.glob(File.join(DOWNLOAD_DIR, "*.csv")).each do |f|
        next unless File.basename(f).start_with?(region_prefix(filename))

        if File.size(f) < MIN_VALID_SIZE
          Rails.logger.warn("[MIUR] rimuovo file precedente vuoto: #{File.basename(f)}")
          File.delete(f)
          next
        end

        match = File.basename(f).match(/(\d{8})\.csv/)
        return [f, match[1]]
      end
      [nil, nil]
    end

    def find_archived_csv(filename_pattern)
      prefix = region_prefix(filename_pattern)
      candidates = Dir.glob(File.join(DOWNLOAD_DIR, "*", "*.csv")).select do |archived|
        File.basename(archived).start_with?(prefix) && File.size(archived) >= MIN_VALID_SIZE
      end
      candidates.max_by { |f| File.basename(f) }
    end

    def region_prefix(filename)
      filename.split("0000").first
    end

    def archive_file(file, date)
      archive_dir = File.join(DOWNLOAD_DIR, date)
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
      # NOTE: regioni_stale (fallback CSV) non triggera import: il file è già a disco
      # e verrà incluso dal task import:new_adozioni quando ci sono comunque aggiornate/nuove.
      if @regioni_aggiornate.empty? && @regioni_nuove.empty?
        Rails.logger.info "Nessuna regione aggiornata o nuova, skip import"
        return
      end

      csv_count = Dir.glob(File.join(DOWNLOAD_DIR, "*.csv")).size
      if csv_count < MIN_CSV_FOR_IMPORT
        Rails.logger.error "[MIUR] SKIP IMPORT: solo #{csv_count}/#{MIN_CSV_FOR_IMPORT} CSV presenti. Non eseguo TRUNCATE."
        return
      end

      Rake::Task['import:new_adozioni'].reenable
      Rake::Task['import:cambia_religione'].reenable
      Rake::Task['controllo_adozioni:rebuild'].reenable
      Rake::Task['import:new_adozioni'].invoke("true")
      Rake::Task['import:cambia_religione'].invoke
      Rake::Task['controllo_adozioni:rebuild'].invoke
    end

    def notify
      ScrapingNotificationJob.perform_async(@regioni_aggiornate, @regioni_saltate, @regioni_nuove, @regioni_fallite, @regioni_stale)
    end
  end
end
