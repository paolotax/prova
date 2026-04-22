require "test_helper"

# Silent subclass: stubs expensive internals and broadcasts so we can focus
# on the enqueue-behavior assertion without touching the DB heavily.
class ImportScuolePerZonaJobSilent < ImportScuolePerZonaJob
  private
  def import_codici(_account_zona) = []
  def import_scuole_batch(_account, _account_zona, _codici) = nil
  def import_classi_batch(_account, _codici) = nil
  def import_adozioni_batch(_account, _codici) = nil
  def broadcast_zone_panel(_account) = nil
  def broadcast_scuole_refresh(_account) = nil
end

class ImportScuolePerZonaJobTest < ActiveJob::TestCase
  fixtures :accounts, :users, :memberships, :account_zone

  setup do
    @zona = account_zone(:fizzy_mi_primaria)
  end

  test "does not enqueue UpdateMieAdozioniJob anymore" do
    assert_no_enqueued_jobs(only: UpdateMieAdozioniJob) do
      ImportScuolePerZonaJobSilent.perform_now(@zona)
    end
  end
end
