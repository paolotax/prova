require "test_helper"

# Alias kept so existing tests can keep using the Silent name; the shared/toast
# partial now exists (Task 5), so no override is needed — the real broadcast runs.
UpdateMieAdozioniJobSilent = UpdateMieAdozioniJob

# Forces the body to raise so we can verify the advisory lock is released in ensure.
class UpdateMieAdozioniJobRaising < UpdateMieAdozioniJob
  private
  def esegui_aggiornamento(account, provincia)
    raise "boom"
  end
end

class UpdateMieAdozioniJobTest < ActiveJob::TestCase
  fixtures :accounts, :users, :memberships, :editori, :categorie, :libri, :mandati, :scuole, :classi, :adozioni

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

  test "sezioni_count conta solo l'anno corrente (classi attive)" do
    UpdateMieAdozioniJobSilent.perform_now(@fizzy)
    mandato = mandati(:fizzy_zanichelli)
    base = mandato.reload.sezioni_count

    scuola = scuole(:scuola_fizzy)
    archiviata = @fizzy.classi.create!(scuola: scuola, anno_scolastico: "202425",
      anno_corso: "4", sezione: "Z", stato: "archiviata",
      codice_ministeriale_origine: scuola.codice_ministeriale,
      classe_origine: "4", sezione_origine: "Z")
    @fizzy.adozioni.create!(classe: archiviata, codice_isbn: "9999990001",
      anno_scolastico: "202425", editore: "Zanichelli", da_acquistare: true)

    UpdateMieAdozioniJobSilent.perform_now(@fizzy)
    assert_equal base, mandato.reload.sezioni_count,
      "l'annata archiviata non deve contare nel counter del mandato"

    attiva = @fizzy.classi.create!(scuola: scuola, anno_scolastico: "202526",
      anno_corso: "5", sezione: "Z", stato: "attiva",
      codice_ministeriale_origine: scuola.codice_ministeriale,
      classe_origine: "5", sezione_origine: "Z")
    @fizzy.adozioni.create!(classe: attiva, codice_isbn: "9999990002",
      anno_scolastico: "202526", editore: "Zanichelli", da_acquistare: true)

    UpdateMieAdozioniJobSilent.perform_now(@fizzy)
    assert_equal base + 1, mandato.reload.sezioni_count,
      "l'annata corrente su classe attiva deve contare"
  end

  test "adozioni_count dei libri esclude anni storici e classi non attive" do
    libro = libri(:libro_fizzy)
    scuola = scuole(:scuola_fizzy)
    archiviata = @fizzy.classi.create!(scuola: scuola, anno_scolastico: "202425",
      anno_corso: "4", sezione: "Y", stato: "archiviata",
      codice_ministeriale_origine: scuola.codice_ministeriale,
      classe_origine: "4", sezione_origine: "Y")
    @fizzy.adozioni.create!(classe: archiviata, libro: libro,
      codice_isbn: libro.codice_isbn, anno_scolastico: "202425",
      editore: "Zanichelli", da_acquistare: true)

    UpdateMieAdozioniJobSilent.perform_now(@fizzy)
    assert_equal 0, libro.reload.adozioni_count,
      "l'adozione della classe archiviata non deve contare"

    attiva = @fizzy.classi.create!(scuola: scuola, anno_scolastico: "202526",
      anno_corso: "5", sezione: "Y", stato: "attiva",
      codice_ministeriale_origine: scuola.codice_ministeriale,
      classe_origine: "5", sezione_origine: "Y")
    @fizzy.adozioni.create!(classe: attiva, libro: libro,
      codice_isbn: libro.codice_isbn, anno_scolastico: "202526",
      editore: "Zanichelli", da_acquistare: true)

    UpdateMieAdozioniJobSilent.perform_now(@fizzy)
    assert_equal 1, libro.reload.adozioni_count,
      "deve contare solo l'adozione dell'anno della classe attiva"
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
