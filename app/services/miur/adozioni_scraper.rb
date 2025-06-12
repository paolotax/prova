require 'nokogiri'
require 'open-uri'
require 'net/http'
require 'fileutils'

module Miur
  class AdozioniScraper
    DOWNLOAD_DIR = Rails.root.join('tmp', '_miur', 'adozioni')
    BASE_URL = 'https://dati.istruzione.it/opendata/opendata/catalogo/elements1'

    attr_reader :regioni_aggiornate, :regioni_saltate, :regioni_nuove

    def initialize
      @regioni_aggiornate = []
      @regioni_saltate = []
      @regioni_nuove = []
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
      doc = Nokogiri::HTML(URI.open("#{BASE_URL}/?area=Adozioni%20libri%20di%20testo"))
      cards = doc.css('.card')
      downloaded_files = {}

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
        elsif existing_file
          archive_file(existing_file, existing_date)
          @regioni_aggiornate << region
        else
          @regioni_nuove << region
        end

        download_file(csv_url, filepath)
      end
    end

    def clean_region_name(text)
      text.gsub('Adozioni libri di testo scolastici. Regione ', '').gsub('.', '').upcase
    end

    def parse_data(raw_data)
      raw_data.gsub('Modified: ', '').split('/').reverse.join
    end

    def find_existing_file(filename)
      Dir.glob(File.join(DOWNLOAD_DIR, "*.csv")).each do |f|
        if File.basename(f).start_with?(filename.split('0000').first)
          match = File.basename(f).match(/(\d{8})\.csv/)
          return [f, match[1]]
        end
      end
      [nil, nil]
    end

    def archive_file(file, date)
      archive_dir = File.join(DOWNLOAD_DIR, date)
      FileUtils.mkdir_p(archive_dir)
      FileUtils.mv(file, File.join(archive_dir, File.basename(file)))
    end

    def download_file(url, path)
      response = URI.open(url)
      File.open(path, 'wb') { |f| f.write(response.read) }
    end

    def process_imports
      Rake::Task['import:splitta_adozioni'].reenable
      Rake::Task['import:new_adozioni'].reenable
      Rake::Task['import:cambia_religione'].reenable
      Rake::Task['scrape:delete_adozioni'].reenable

      Rake::Task['import:splitta_adozioni'].invoke
      Rake::Task['import:new_adozioni'].invoke("true")
      Rake::Task['import:cambia_religione'].invoke
      Rake::Task['scrape:delete_adozioni'].invoke("true")
    end

    def notify
      ScrapingNotificationJob.perform_async(@regioni_aggiornate, @regioni_saltate, @regioni_nuove)
    end
  end
end
