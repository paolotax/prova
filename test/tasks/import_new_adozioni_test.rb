require "test_helper"
require "rake"

class ImportNewAdozioniTaskTest < ActiveSupport::TestCase
  setup do
    Rails.application.load_tasks if Rake::Task.tasks.empty?
    @tmp_csv_dir = Rails.root.join("tmp", "_miur_test_#{SecureRandom.hex(4)}", "adozioni")
    FileUtils.mkdir_p(@tmp_csv_dir)
  end

  teardown do
    Dir.unstub(:glob)
    FileUtils.rm_rf(@tmp_csv_dir.parent)
    Rake::Task["import:new_adozioni"].reenable
  end

  def stub_csv_glob(files)
    expected_pattern = Rails.root.join("tmp", "_miur", "adozioni", "*.csv").to_s
    Dir.unstub(:glob)
    Dir.stubs(:glob).with do |arg|
      arg.to_s == expected_pattern
    end.returns(files)
  end

  test "aborta se ci sono meno di MIN_CSV_THRESHOLD CSV" do
    # Build list of paths but do NOT create the files — task should abort before trying to open them
    fake_files = 5.times.map { |i| @tmp_csv_dir.join("ALTREG#{i}.csv").to_s }
    stub_csv_glob(fake_files)

    rows_before = NewAdozione.count
    assert_raises(SystemExit) do
      Rake::Task["import:new_adozioni"].invoke("true")
    end
    assert_equal rows_before, NewAdozione.count, "TRUNCATE non deve essere eseguito"
  end

  test "procede normalmente se ci sono >= MIN_CSV_THRESHOLD CSV" do
    # Create real minimal CSV files so the task can iterate over them
    fake_files = 20.times.map do |i|
      path = @tmp_csv_dir.join("ALTREG#{i}.csv").to_s
      File.write(path, "ANNOCORSO,CODICESCUOLA,TITOLO\n")
      path
    end
    stub_csv_glob(fake_files)

    # Stub TRUNCATE to avoid touching real DB
    NewAdozione.connection.stubs(:execute).with(regexp_matches(/TRUNCATE/)).returns(true)
    # Stub the import too — we don't want it to actually parse the fake CSVs
    NewAdozione.stubs(:import).returns(true)

    # Should NOT abort
    assert_nothing_raised do
      Rake::Task["import:new_adozioni"].invoke("true")
    end
  end
end
