require "test_helper"

class RebuildAccountAdozioniJobTest < ActiveJob::TestCase
  fixtures :accounts

  setup do
    @account = accounts(:fizzy)
  end

  test "calls BackfillDirezioniJob and UpdateMieAdozioniJob in sequence" do
    sequence = []

    backfill_orig = BackfillDirezioniJob.method(:perform_now)
    update_orig = UpdateMieAdozioniJob.method(:perform_now)

    BackfillDirezioniJob.define_singleton_method(:perform_now) { |_a| sequence << :backfill }
    UpdateMieAdozioniJob.define_singleton_method(:perform_now) { |_a| sequence << :update }

    begin
      RebuildAccountAdozioniJob.perform_now(@account)
    ensure
      BackfillDirezioniJob.define_singleton_method(:perform_now, backfill_orig)
      UpdateMieAdozioniJob.define_singleton_method(:perform_now, update_orig)
    end

    assert_equal [:backfill, :update], sequence
  end
end
