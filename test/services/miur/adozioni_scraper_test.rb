require "test_helper"
require "webmock/minitest"
require "fileutils"

module Miur
  class AdozioniScraperTest < ActiveSupport::TestCase
    setup do
      @tmp_dir = Rails.root.join("tmp", "test_miur_adozioni_#{SecureRandom.hex(4)}")
      FileUtils.mkdir_p(@tmp_dir)
      @original_dir = Miur::AdozioniScraper::DOWNLOAD_DIR
      Miur::AdozioniScraper.send(:remove_const, :DOWNLOAD_DIR)
      Miur::AdozioniScraper.const_set(:DOWNLOAD_DIR, @tmp_dir)
    end

    teardown do
      FileUtils.rm_rf(@tmp_dir)
      Miur::AdozioniScraper.send(:remove_const, :DOWNLOAD_DIR)
      Miur::AdozioniScraper.const_set(:DOWNLOAD_DIR, @original_dir)
    end

    test "smoke: scraper instance esiste e ha 4 contatori vuoti" do
      scraper = Miur::AdozioniScraper.new
      assert_equal [], scraper.regioni_aggiornate
      assert_equal [], scraper.regioni_saltate
      assert_equal [], scraper.regioni_nuove
      assert_equal [], scraper.regioni_fallite
    end

    test "skip regione se CSV già presente e data MIUR uguale" do
      filename = "ALTUMBRIA000020260525.csv"
      filepath = @tmp_dir.join(filename)
      File.write(filepath, "x" * (Miur::AdozioniScraper::MIN_VALID_SIZE + 1))

      catalog_html = <<~HTML
        <div class="card">
          <h3>Adozioni libri di testo scolastici. Regione Umbria.</h3>
          <span class="dettaglio-data">Modified: 25/05/2026</span>
          <a class="csv" href="#{filename}">CSV</a>
        </div>
      HTML

      stub_request(:get, %r{dati\.istruzione\.it.*Adozioni}).to_return(body: catalog_html, status: 200)

      scraper = Miur::AdozioniScraper.new
      scraper.send(:scrape_adozioni)

      assert_includes scraper.regioni_saltate, "UMBRIA"
      assert_empty scraper.regioni_aggiornate
      assert_empty scraper.regioni_fallite
    end
  end
end
