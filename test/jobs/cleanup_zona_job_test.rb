require "test_helper"

class CleanupZonaJobTest < ActiveJob::TestCase
  fixtures :accounts, :users, :memberships, :account_zone, :scuole, :classi, :adozioni

  setup do
    @fizzy = accounts(:fizzy)
    @zona = account_zone(:fizzy_mi_primaria)
    @zona.update!(stato: "pulizia")
  end

  test "destroys scuole matching provincia and grado" do
    assert_difference("Scuola.count", -1) do
      CleanupZonaJob.perform_now(@zona)
    end
  end

  test "destroys the account_zona record" do
    assert_difference("AccountZona.count", -1) do
      CleanupZonaJob.perform_now(@zona)
    end
  end

  test "cascades to classi and adozioni" do
    assert_difference("Classe.count", -3) do
      assert_difference("Adozione.count", -5) do
        CleanupZonaJob.perform_now(@zona)
      end
    end
  end

  test "discards on deserialization error" do
    @zona.destroy!
    assert_nothing_raised do
      CleanupZonaJob.perform_now(@zona)
    end
  end
end
