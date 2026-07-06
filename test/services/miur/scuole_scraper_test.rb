require "test_helper"
require "rake"
require "webmock/minitest"
require "fileutils"

module Miur
  class ScuoleScraperTest < ActiveSupport::TestCase
    setup do
      @tmp_dir = Rails.root.join("tmp", "test_miur_scuole_#{SecureRandom.hex(4)}")
      FileUtils.mkdir_p(@tmp_dir)
      @original_dir = Miur::ScuoleScraper::DOWNLOAD_DIR
      Miur::ScuoleScraper.send(:remove_const, :DOWNLOAD_DIR)
      Miur::ScuoleScraper.const_set(:DOWNLOAD_DIR, @tmp_dir)
    end

    teardown do
      FileUtils.rm_rf(@tmp_dir)
      Miur::ScuoleScraper.send(:remove_const, :DOWNLOAD_DIR)
      Miur::ScuoleScraper.const_set(:DOWNLOAD_DIR, @original_dir)
    end

    # Catalogo con tutti e 4 i dataset, ciascuno con un anno vecchio e uno nuovo:
    # lo scraper deve tenere solo il filename più recente per dataset.
    def catalog_html
      <<~HTML
        <div class="card"><a class="csv" href="SCUANAGRAFESTAT20252620250901.csv">CSV</a></div>
        <div class="card"><a class="csv" href="SCUANAGRAFESTAT20262720260901.csv">CSV</a></div>
        <div class="card"><a class="csv" href="SCUANAGRAFEPAR20262720260901.csv">CSV</a></div>
        <div class="card"><a class="csv" href="SCUANAAUTSTAT20262720260901.csv">CSV</a></div>
        <div class="card"><a class="csv" href="SCUANAAUTPAR20262720260901.csv">CSV</a></div>
        <div class="card"><a class="csv" href="SCUOLEMENSEEDIFICI20262720260901.csv">CSV</a></div>
      HTML
    end

    test "smoke: scraper instance esiste e ha 5 contatori vuoti" do
      scraper = Miur::ScuoleScraper.new
      assert_equal [], scraper.dataset_aggiornati
      assert_equal [], scraper.dataset_saltati
      assert_equal [], scraper.dataset_nuovi
      assert_equal [], scraper.dataset_falliti
      assert_equal [], scraper.dataset_stale
    end

    test "tiene solo l'anno più recente per dataset e ignora dataset non anagrafici" do
      stub_request(:get, %r{area=Scuole}).to_return(body: catalog_html, status: 200)
      stub_request(:get, %r{SCUANA.*\.csv}).to_return(body: "x" * (Miur::ScuoleScraper::MIN_VALID_SIZE + 1), status: 200)

      scraper = Miur::ScuoleScraper.new
      scraper.stubs(:retry_sleep).returns(0)
      scraper.send(:scrape_scuole)

      assert_equal Miur::ScuoleScraper::DATASETS.sort, scraper.dataset_nuovi.sort
      assert_empty scraper.dataset_falliti
      # scarica il 2026 e non il 2025
      assert File.exist?(@tmp_dir.join("SCUANAGRAFESTAT20262720260901.csv"))
      assert_not File.exist?(@tmp_dir.join("SCUANAGRAFESTAT20252620250901.csv"))
    end

    test "salta il dataset se il CSV più recente è già a disco" do
      File.write(@tmp_dir.join("SCUANAGRAFESTAT20262720260901.csv"), "x" * (Miur::ScuoleScraper::MIN_VALID_SIZE + 1))
      File.write(@tmp_dir.join("SCUANAGRAFEPAR20262720260901.csv"), "x" * (Miur::ScuoleScraper::MIN_VALID_SIZE + 1))
      File.write(@tmp_dir.join("SCUANAAUTSTAT20262720260901.csv"), "x" * (Miur::ScuoleScraper::MIN_VALID_SIZE + 1))
      File.write(@tmp_dir.join("SCUANAAUTPAR20262720260901.csv"), "x" * (Miur::ScuoleScraper::MIN_VALID_SIZE + 1))

      stub_request(:get, %r{area=Scuole}).to_return(body: catalog_html, status: 200)

      scraper = Miur::ScuoleScraper.new
      scraper.send(:scrape_scuole)

      assert_equal Miur::ScuoleScraper::DATASETS.sort, scraper.dataset_saltati.sort
      assert_empty scraper.dataset_nuovi
      assert_empty scraper.dataset_aggiornati
    end

    test "dataset aggiornato: archivia il vecchio CSV quando ne arriva uno nuovo" do
      File.write(@tmp_dir.join("SCUANAGRAFESTAT20252620250901.csv"), "x" * (Miur::ScuoleScraper::MIN_VALID_SIZE + 1))

      stub_request(:get, %r{area=Scuole}).to_return(body: catalog_html, status: 200)
      stub_request(:get, %r{SCUANA.*\.csv}).to_return(body: "x" * (Miur::ScuoleScraper::MIN_VALID_SIZE + 1), status: 200)

      scraper = Miur::ScuoleScraper.new
      scraper.stubs(:retry_sleep).returns(0)
      scraper.send(:scrape_scuole)

      assert_includes scraper.dataset_aggiornati, "SCUANAGRAFESTAT"
      assert File.exist?(@tmp_dir.join("20250901", "SCUANAGRAFESTAT20252620250901.csv")), "il vecchio CSV deve essere archiviato per data"
      assert File.exist?(@tmp_dir.join("SCUANAGRAFESTAT20262720260901.csv"))
    end

    test "dataset finisce in falliti se il download HTTP solleva" do
      stub_request(:get, %r{area=Scuole}).to_return(body: catalog_html, status: 200)
      stub_request(:get, %r{SCUANA.*\.csv}).to_timeout

      scraper = Miur::ScuoleScraper.new
      scraper.stubs(:retry_sleep).returns(0)
      scraper.send(:scrape_scuole)

      assert_equal Miur::ScuoleScraper::DATASETS.sort, scraper.dataset_falliti.sort
      assert_empty scraper.dataset_nuovi
    end

    test "retry: tenta 3 volte prima di marcare il dataset come fallito" do
      stub_request(:get, %r{area=Scuole}).to_return(body: catalog_html, status: 200)
      stub_request(:get, %r{SCUANAGRAFESTAT}).to_timeout
      stub_request(:get, %r{SCUANAGRAFEPAR|SCUANAAUT}).to_return(body: "x" * (Miur::ScuoleScraper::MIN_VALID_SIZE + 1), status: 200)

      scraper = Miur::ScuoleScraper.new
      scraper.stubs(:retry_sleep).returns(0)
      scraper.send(:scrape_scuole)

      assert_includes scraper.dataset_falliti, "SCUANAGRAFESTAT"
      assert_requested :get, %r{SCUANAGRAFESTAT20262720260901}, times: 3
    end

    test "fallback: usa CSV archiviato se il download fallisce definitivamente" do
      archive_dir = @tmp_dir.join("20250901")
      FileUtils.mkdir_p(archive_dir)
      File.write(archive_dir.join("SCUANAGRAFESTAT20252620250901.csv"), "x" * (Miur::ScuoleScraper::MIN_VALID_SIZE + 1))

      stub_request(:get, %r{area=Scuole}).to_return(body: catalog_html, status: 200)
      stub_request(:get, %r{SCUANAGRAFESTAT}).to_timeout
      stub_request(:get, %r{SCUANAGRAFEPAR|SCUANAAUT}).to_return(body: "x" * (Miur::ScuoleScraper::MIN_VALID_SIZE + 1), status: 200)

      scraper = Miur::ScuoleScraper.new
      scraper.stubs(:retry_sleep).returns(0)
      scraper.send(:scrape_scuole)

      assert_includes scraper.dataset_stale, "SCUANAGRAFESTAT"
      assert_not_includes scraper.dataset_falliti, "SCUANAGRAFESTAT"
      assert File.exist?(@tmp_dir.join("SCUANAGRAFESTAT20252620250901.csv")), "il CSV archiviato deve essere ricopiato nella root"
    end

    test "process_imports parte se ci sono >= 4 CSV e dataset aggiornati/nuovi" do
      Miur::ScuoleScraper::DATASETS.each do |ds|
        File.write(@tmp_dir.join("#{ds}20262720260901.csv"), "x")
      end

      task_double = mock("rake_task")
      task_double.expects(:reenable).at_least_once
      task_double.expects(:invoke).at_least_once
      Rake::Task.expects(:[]).with("miur:importa_scuole").returns(task_double).at_least_once

      scraper = Miur::ScuoleScraper.new
      scraper.instance_variable_set(:@dataset_nuovi, Miur::ScuoleScraper::DATASETS.dup)
      scraper.send(:process_imports)
    end

    test "process_imports aggancia gli esiti dataset al run creato dall'import" do
      Miur::ScuoleScraper::DATASETS.each do |ds|
        File.write(@tmp_dir.join("#{ds}20262720260901.csv"), "x")
      end

      creating_task = Object.new
      def creating_task.reenable; end
      def creating_task.invoke(*)
        Miur::ImportRun.create!(dataset: "scuole", anno_scolastico: "202627", completed_at: Time.current)
      end
      Rake::Task.stubs(:[]).with("miur:importa_scuole").returns(creating_task)

      scraper = Miur::ScuoleScraper.new
      scraper.instance_variable_set(:@dataset_aggiornati, ["SCUANAGRAFESTAT"])
      scraper.instance_variable_set(:@dataset_stale, ["SCUANAAUTPAR"])
      scraper.send(:process_imports)

      run = Miur::ImportRun.scuole.order(:id).last
      assert_equal ["SCUANAGRAFESTAT"], run.regioni_aggiornate
      assert_equal ["SCUANAAUTPAR"], run.regioni_stale
      assert_equal [], run.regioni_fallite
    end

    test "process_imports cattura Miur::ImportError senza sollevare e non tocca run stale" do
      Miur::ScuoleScraper::DATASETS.each do |ds|
        File.write(@tmp_dir.join("#{ds}20262720260901.csv"), "x")
      end
      stale_run = Miur::ImportRun.create!(dataset: "scuole", anno_scolastico: "202627", completed_at: 1.day.ago)

      failing_task = Object.new
      def failing_task.reenable; end
      def failing_task.invoke(*) = raise(Miur::ImportError, "lock occupato")
      Rake::Task.stubs(:[]).with("miur:importa_scuole").returns(failing_task)

      scraper = Miur::ScuoleScraper.new
      scraper.instance_variable_set(:@dataset_nuovi, Miur::ScuoleScraper::DATASETS.dup)
      assert_nothing_raised { scraper.send(:process_imports) }

      assert_equal [], stale_run.reload.regioni_aggiornate
    end

    test "process_imports salta import se < 4 CSV" do
      2.times { |i| File.write(@tmp_dir.join("SCUANAGRAFESTAT#{i}.csv"), "x") }
      Rake::Task.expects(:[]).never

      scraper = Miur::ScuoleScraper.new
      scraper.instance_variable_set(:@dataset_nuovi, ["SCUANAGRAFESTAT"])
      scraper.send(:process_imports)
    end
  end
end
