require "test_helper"
require "rake"
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

    test "smoke: scraper instance esiste e ha 5 contatori vuoti" do
      scraper = Miur::AdozioniScraper.new
      assert_equal [], scraper.regioni_aggiornate
      assert_equal [], scraper.regioni_saltate
      assert_equal [], scraper.regioni_nuove
      assert_equal [], scraper.regioni_fallite
      assert_equal [], scraper.regioni_stale
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

    test "regione finisce in fallite se il download HTTP solleva" do
      catalog_html = <<~HTML
        <div class="card">
          <h3>Adozioni libri di testo scolastici. Regione Lombardia.</h3>
          <span class="dettaglio-data">Modified: 25/05/2026</span>
          <a class="csv" href="ALTLOMBARDIA000020260525.csv">CSV</a>
        </div>
      HTML

      stub_request(:get, %r{Adozioni}).to_return(body: catalog_html, status: 200)
      stub_request(:get, %r{ALTLOMBARDIA}).to_timeout

      scraper = Miur::AdozioniScraper.new
      scraper.send(:scrape_adozioni)

      assert_includes scraper.regioni_fallite, "LOMBARDIA"
      assert_empty scraper.regioni_aggiornate
    end

    test "retry: tenta 3 volte prima di marcare regione come fallita" do
      catalog_html = <<~HTML
        <div class="card">
          <h3>Adozioni libri di testo scolastici. Regione Sicilia.</h3>
          <span class="dettaglio-data">Modified: 25/05/2026</span>
          <a class="csv" href="ALTSICILIA000020260525.csv">CSV</a>
        </div>
      HTML

      stub_request(:get, %r{Adozioni}).to_return(body: catalog_html, status: 200)
      stub_request(:get, %r{ALTSICILIA}).to_timeout.then.to_timeout.then
        .to_return(body: "x" * (Miur::AdozioniScraper::MIN_VALID_SIZE + 1), status: 200)

      scraper = Miur::AdozioniScraper.new
      scraper.stubs(:retry_sleep).returns(0)
      scraper.send(:scrape_adozioni)

      assert_includes scraper.regioni_nuove, "SICILIA"
      assert_empty scraper.regioni_fallite
    end

    test "retry: dopo 3 tentativi falliti la regione finisce in fallite" do
      catalog_html = <<~HTML
        <div class="card">
          <h3>Adozioni libri di testo scolastici. Regione Molise.</h3>
          <span class="dettaglio-data">Modified: 25/05/2026</span>
          <a class="csv" href="ALTMOLISE000020260525.csv">CSV</a>
        </div>
      HTML

      stub_request(:get, %r{Adozioni}).to_return(body: catalog_html, status: 200)
      stub_request(:get, %r{ALTMOLISE}).to_timeout

      scraper = Miur::AdozioniScraper.new
      scraper.stubs(:retry_sleep).returns(0)
      scraper.send(:scrape_adozioni)

      assert_includes scraper.regioni_fallite, "MOLISE"
      assert_empty scraper.regioni_nuove
      assert_requested :get, %r{ALTMOLISE}, times: 3
    end

    test "notify passa regioni_stale al job di notifica" do
      ScrapingNotificationJob.expects(:perform_async).with([], [], [], [], includes("MOLISE"))
      scraper = Miur::AdozioniScraper.new
      scraper.instance_variable_set(:@regioni_stale, ["MOLISE"])
      scraper.send(:notify)
    end

    test "fallback: usa CSV archiviato se download fallisce definitivamente" do
      archive_dir = @tmp_dir.join("20260520")
      FileUtils.mkdir_p(archive_dir)
      archive_file = archive_dir.join("ALTMOLISE000020260520.csv")
      File.write(archive_file, "x" * (Miur::AdozioniScraper::MIN_VALID_SIZE + 1))

      catalog_html = <<~HTML
        <div class="card">
          <h3>Adozioni libri di testo scolastici. Regione Molise.</h3>
          <span class="dettaglio-data">Modified: 25/05/2026</span>
          <a class="csv" href="ALTMOLISE000020260525.csv">CSV</a>
        </div>
      HTML

      stub_request(:get, %r{Adozioni}).to_return(body: catalog_html, status: 200)
      stub_request(:get, %r{ALTMOLISE}).to_timeout

      scraper = Miur::AdozioniScraper.new
      scraper.stubs(:retry_sleep).returns(0)
      scraper.send(:scrape_adozioni)

      assert_includes scraper.regioni_stale, "MOLISE"
      assert_not_includes scraper.regioni_fallite, "MOLISE"
      assert File.exist?(@tmp_dir.join("ALTMOLISE000020260520.csv")), "il CSV archiviato deve essere ricopiato nella root"
    end

    test "process_imports parte se >= 18 CSV in DOWNLOAD_DIR" do
      18.times { |i| File.write(@tmp_dir.join("ALTREG#{i}000020260525.csv"), "x") }

      task_double = mock("rake_task")
      task_double.expects(:reenable).at_least_once
      task_double.expects(:invoke).at_least_once
      Rake::Task.expects(:[]).with("import:new_adozioni").returns(task_double).at_least_once
      Rake::Task.expects(:[]).with("import:cambia_religione").returns(task_double).at_least_once

      scraper = Miur::AdozioniScraper.new
      scraper.instance_variable_set(:@regioni_aggiornate, ["A", "B"])
      scraper.send(:process_imports)
    end

    test "process_imports salta import se < 18 CSV in DOWNLOAD_DIR" do
      5.times { |i| File.write(@tmp_dir.join("ALTREG#{i}.csv"), "x") }
      Rake::Task.expects(:[]).never

      scraper = Miur::AdozioniScraper.new
      scraper.instance_variable_set(:@regioni_aggiornate, ["A"])
      scraper.send(:process_imports)
    end
  end
end
