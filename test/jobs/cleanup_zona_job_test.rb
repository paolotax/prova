require "test_helper"

# Silent subclass: overrides broadcast methods that require view rendering/jobs.
# pulsante_aggiorna_adozioni partial now exists (Task 4), so broadcast_pulsante_stato
# runs for real.
class CleanupZonaJobSilent < CleanupZonaJob
  private
  def broadcast_zone_panel(account); end
  def broadcast_scuole_refresh(account); end
end

class CleanupZonaJobTest < ActiveJob::TestCase
  fixtures :accounts, :users, :memberships, :account_zone, :scuole, :classi, :adozioni

  setup do
    @fizzy = accounts(:fizzy)
    @zona = account_zone(:fizzy_mi_primaria)
    @zona.update!(stato: "pulizia")
  end

  test "destroys scuole matching provincia and grado" do
    assert_difference("Scuola.count", -3) do
      CleanupZonaJobSilent.perform_now(@zona)
    end
  end

  test "destroys the account_zona record" do
    assert_difference("Accounts::Zona.count", -1) do
      CleanupZonaJobSilent.perform_now(@zona)
    end
  end

  test "cascades to classi and adozioni" do
    assert_difference("Classe.count", -5) do
      assert_difference("Adozione.count", -7) do
        CleanupZonaJobSilent.perform_now(@zona)
      end
    end
  end

  test "discards on deserialization error" do
    @zona.destroy!
    assert_nothing_raised do
      CleanupZonaJobSilent.perform_now(@zona)
    end
  end

  test "does not enqueue UpdateMieAdozioniJob anymore" do
    assert_no_enqueued_jobs(only: UpdateMieAdozioniJob) do
      CleanupZonaJobSilent.perform_now(@zona)
    end
  end
end
