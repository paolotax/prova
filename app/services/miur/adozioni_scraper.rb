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

    attr_reader :regioni_aggiornate, :regioni_saltate, :regioni_nuove, :regioni_fallite

    def initialize
      @regioni_aggiornate = []
      @regioni_saltate = []
      @regioni_nuove = []
      @regioni_fallite = []
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
      Rails.logger.info("[MIUR] #{region}: download start")
      started_at = Time.current

      bytes = download_file(csv_url, filepath)

      if bytes < MIN_VALID_SIZE
        File.delete(filepath) if File.exist?(filepath)
        Rails.logger.warn("[MIUR] #{region}: scaricati solo #{bytes} byte, file rimosso")
        @regioni_fallite << region
        return
      end

      if existing_file
        archive_file(existing_file, existing_date)
        @regioni_aggiornate << region
      else
        @regioni_nuove << region
      end

      elapsed = (Time.current - started_at).round(1)
      Rails.logger.info("[MIUR] #{region}: ok #{bytes} byte in #{elapsed}s")
    rescue => e
      File.delete(filepath) if File.exist?(filepath) && File.size(filepath) < MIN_VALID_SIZE
      Rails.logger.error("[MIUR] #{region}: errore download — #{e.class}: #{e.message}")
      @regioni_fallite << region
    end

    def clean_region_name(text)
      text.gsub('Adozioni libri di testo scolastici. Regione ', '').gsub('.', '').upcase
    end

    def parse_data(raw_data)
      raw_data.gsub('Modified: ', '').split('/').reverse.join
    end

    def find_existing_file(filename)
      Dir.glob(File.join(DOWNLOAD_DIR, "*.csv")).each do |f|
        next unless File.basename(f).start_with?(filename.split('0000').first)

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
      if @regioni_aggiornate.empty? && @regioni_nuove.empty?
        Rails.logger.info "Nessuna regione aggiornata o nuova, skip import"
        return
      end

      Rake::Task['import:new_adozioni'].reenable
      Rake::Task['import:cambia_religione'].reenable

      Rake::Task['import:new_adozioni'].invoke("true")
      Rake::Task['import:cambia_religione'].invoke
    end

    def notify
      ScrapingNotificationJob.perform_async(@regioni_aggiornate, @regioni_saltate, @regioni_nuove, @regioni_fallite)
    end
  end
end
