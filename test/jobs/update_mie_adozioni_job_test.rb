require "test_helper"

# Silent subclass: overrides broadcast_notifica_completamento so tests don't depend
# on the shared/toast partial that lands in Task 5. The pulsante partial now exists
# (Task 4), so broadcast_pulsante_stato runs for real.
class UpdateMieAdozioniJobSilent < UpdateMieAdozioniJob
  private
  def broadcast_notifica_completamento(account); end
end

# Forces the body to raise so we can verify the advisory lock is released in ensure.
class UpdateMieAdozioniJobRaising < UpdateMieAdozioniJobSilent
  private
  def esegui_aggiornamento(account, provincia)
    raise "boom"
  end
end

class UpdateMieAdozioniJobTest < ActiveJob::TestCase
  fixtures :accounts, :users, :memberships, :editori, :mandati, :scuole, :classi, :adozioni

  setup do
    @fizzy = accounts(:fizzy)
  end

  test "sets mia=true for adozioni matching mandato editore" do
    # fizzy has mandato for Zanichelli (no provincia/grado filter = covers all)
    # adozione_italiano_1a has editore: "Zanichelli"
    UpdateMieAdozioniJobSilent.perform_now(@fizzy)

    adozione_zanichelli = adozioni(:adozione_italiano_1a)
    adozione_pearson = adozioni(:adozione_matematica_1a)

    adozione_zanichelli.reload
    adozione_pearson.reload

    assert adozione_zanichelli.mia?, "Zanichelli adoption should be mia"
    assert_not adozione_pearson.mia?, "Pearson adoption should not be mia"
  end

  test "resets mia=false before applying" do
    adozione = adozioni(:adozione_matematica_1a)
    adozione.update_column(:mia, true)

    UpdateMieAdozioniJobSilent.perform_now(@fizzy)

    adozione.reload
    assert_not adozione.mia?, "Pearson adoption should be reset to not mia"
  end

  test "respects provincia filter on mandato" do
    acme = accounts(:acme)
    # acme has mandato for Zanichelli with provincia: "RM", grado: "N"
    # scuola_acme is in RM with grado N
    UpdateMieAdozioniJobSilent.perform_now(acme)

    adozione_rm = adozioni(:adozione_fisica_acme)
    adozione_rm.reload

    assert adozione_rm.mia?, "Zanichelli adoption in RM should be mia"
  end

  test "mandato with area only matches schools in that area" do
    UpdateMieAdozioniJobSilent.perform_now(@fizzy)

    assert adozioni(:adozione_nord_pearson).reload.mia?,
      "Pearson adoption in Nord area should be mia"
    assert_not adozioni(:adozione_sud_pearson).reload.mia?,
      "Pearson adoption in Sud area should NOT be mia"
  end

  test "mandato without area matches all schools in provincia" do
    UpdateMieAdozioniJobSilent.perform_now(@fizzy)

    assert adozioni(:adozione_italiano_1a).reload.mia?,
      "Zanichelli adoption should be mia (mandato without area)"
  end

  test "sets adozioni_aggiornamento_started_at on entry and adozioni_aggiornate_at at end" do
    @fizzy.update_columns(adozioni_aggiornamento_started_at: nil, adozioni_aggiornate_at: nil)

    UpdateMieAdozioniJobSilent.perform_now(@fizzy)
    @fizzy.reload

    assert_not_nil @fizzy.adozioni_aggiornamento_started_at
    assert_not_nil @fizzy.adozioni_aggiornate_at
    assert @fizzy.adozioni_aggiornate_at >= @fizzy.adozioni_aggiornamento_started_at
  end

  test "skips body when advisory lock is already held" do
    @fizzy.update_columns(adozioni_aggiornate_at: 1.hour.ago, adozioni_aggiornamento_started_at: nil)
    lock_key = Zlib.crc32("update_mie_adozioni:#{@fizzy.id}")

    # In transactional tests the connection pool pins to a single backend, so
    # `checkout` returns the same session and PG advisory locks are re-entrant.
    # Open a raw PG connection using the same config to simulate "another session".
    db_config = ActiveRecord::Base.connection_db_config.configuration_hash
    other_conn = PG.connect(
      host: db_config[:host],
      port: db_config[:port],
      user: db_config[:username],
      password: db_config[:password],
      dbname: db_config[:database]
    )
    begin
      other_conn.exec("SELECT pg_advisory_lock(#{lock_key})")
      prima = @fizzy.adozioni_aggiornate_at
      UpdateMieAdozioniJobSilent.perform_now(@fizzy)
      @fizzy.reload
      assert_equal prima.to_i, @fizzy.adozioni_aggiornate_at.to_i,
        "timestamp must not advance when lock is held by another session"
      assert_nil @fizzy.adozioni_aggiornamento_started_at,
        "started_at must not be set when lock is held"
    ensure
      other_conn.exec("SELECT pg_advisory_unlock(#{lock_key})") rescue nil
      other_conn.close rescue nil
    end
  end

  test "releases advisory lock when body raises" do
    lock_key = Zlib.crc32("update_mie_adozioni:#{@fizzy.id}")

    assert_raises(RuntimeError) { UpdateMieAdozioniJobRaising.perform_now(@fizzy) }

    acquired = ActiveRecord::Base.connection
      .exec_query("SELECT pg_try_advisory_lock(#{lock_key}) AS got")
      .first["got"]
    assert acquired, "lock must be released in ensure block after raise"
  ensure
    ActiveRecord::Base.connection.exec_query("SELECT pg_advisory_unlock(#{lock_key})") rescue nil
  end
end
