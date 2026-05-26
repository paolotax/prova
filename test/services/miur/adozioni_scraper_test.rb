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
  end
end
