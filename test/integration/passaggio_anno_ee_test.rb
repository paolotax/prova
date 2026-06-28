require "test_helper"

# Test di integrazione end-to-end dello scorrimento d'anno per la PRIMARIA (EE).
# Esercita il flusso reale (modello + controller + job, niente mock) e verifica
# gli invarianti di storicizzazione: vecchie classi/adozioni taggate con l'anno
# di partenza, nuove con l'anno target, nuove prime da new_adozioni, spostamento
# insegnanti e idempotenza del doppio run.
class PassaggioAnnoEeTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  fixtures :accounts, :users, :memberships, :scuole, :classi, :adozioni,
           :new_adozioni, :new_scuole, :persone, :persona_classi

  setup do
    @account = accounts(:fizzy)
    @user = users(:one)
    Current.account = @account
  end

  teardown do
    Current.account = nil
  end

  test "scorrimento completo via modello: storicizza, crea nuove prime, sposta la maestra ed è idempotente" do
    scuola = scuole(:primaria_attiva)

    # Catturo gli id delle classi PRIMA dell'avanzamento (anno_corso cambia in-place).
    quinta_id  = classi(:pa_5a).id
    avanzamenti = {
      classi(:pa_1a).id => "2",
      classi(:pa_2a).id => "3",
      classi(:pa_3a).id => "4",
      classi(:pa_4a).id => "5"
    }
    maestra_pc = persona_classi(:maestra_quinta)
    maestra    = maestra_pc.persona

    scuola.promuovi_primaria!(da: "202526", a: "202627",
                              spostamenti_insegnanti: { maestra_pc.id => "A" })
    scuola.reload

    # --- La quinta uscente è archiviata, resta anno 5 / 202526 ---
    quinta = Classe.find(quinta_id)
    assert_equal "archiviata", quinta.stato
    assert_equal "5", quinta.anno_corso
    assert_equal "202526", quinta.anno_scolastico

    # --- Le ex 1ª..4ª sono avanzate a 2..5, attive, anno 202627, origine = codice scuola ---
    avanzamenti.each do |classe_id, atteso|
      classe = Classe.find(classe_id)
      assert_equal atteso, classe.anno_corso, "la classe #{classe_id} doveva avanzare a #{atteso}"
      assert_equal "attiva", classe.stato
      assert_equal "202627", classe.anno_scolastico
      assert_equal scuola.codice_ministeriale, classe.codice_ministeriale_origine
    end

    # --- Le vecchie adozioni restano taggate 202526 (snapshot preservato) ---
    assert scuola.adozioni.where(anno_scolastico: "202526").exists?,
           "lo snapshot delle adozioni 202526 deve sopravvivere"
    # --- E sono state costruite le nuove adozioni 202627 ---
    assert scuola.adozioni.where(anno_scolastico: "202627").exists?,
           "devono esistere adozioni per il nuovo anno 202627"

    # --- Le nuove prime (anno 1 / 202627) sono state create da new_adozioni ---
    nuova_prima = scuola.classi.attive.find_by(anno_corso: "1", sezione: "A", anno_scolastico: "202627")
    assert nuova_prima, "la nuova prima 202627 deve essere creata da new_adozioni"
    assert scuola.adozioni.where(classe_id: nuova_prima.id, anno_scolastico: "202627").exists?,
           "la nuova prima deve avere le sue adozioni 202627"

    # --- La maestra della quinta è ora legata alla nuova prima A 202627 ---
    assert PersonaClasse.exists?(persona_id: maestra.id, classe_id: nuova_prima.id),
           "la maestra deve essere spostata sulla nuova prima"

    # --- Idempotenza: un secondo run non riavanza né duplica ---
    attive_prima = scuola.classi.attive.count
    adozioni_prima = scuola.adozioni.count
    pc_prima = PersonaClasse.where(classe_id: nuova_prima.id).count

    scuola.promuovi_primaria!(da: "202526", a: "202627",
                              spostamenti_insegnanti: { maestra_pc.id => "A" })
    scuola.reload

    assert_equal attive_prima, scuola.classi.attive.count, "le classi attive non devono cambiare"
    assert_equal adozioni_prima, scuola.adozioni.count, "le adozioni non devono duplicarsi"
    assert_equal pc_prima, PersonaClasse.where(classe_id: nuova_prima.id).count,
                 "lo spostamento insegnanti non deve duplicarsi"
  end

  test "cambio codice via controller: aggiorna la scuola, annota il vecchio codice e accoda il job" do
    sign_in_as(@user, @account)
    scuola = scuole(:primaria_attiva)
    vecchio = scuola.codice_ministeriale

    assert_enqueued_with(job: ScuolaPromuoviClassiJob) do
      post controllo_adozioni_promozione_path(codicescuola: vecchio, account_id: @account.id),
           params: { da: "202526", a: "202627", codice_nuovo: "BOEE999999" }
    end
    assert_redirected_to scuola_path(scuola, account_id: @account.id)

    scuola.reload
    assert_equal "BOEE999999", scuola.codice_ministeriale
    assert_includes scuola.note.to_s, vecchio
  end

  private

  def sign_in_as(user, account)
    session = user.sessions.create!(account: account)
    cookies[:session_token] = sign_cookie(session.token)

    Current.user = user
    Current.account = account
  end

  def sign_cookie(value)
    key_generator = Rails.application.key_generator
    secret = key_generator.generate_key("signed cookie")
    verifier = ActiveSupport::MessageVerifier.new(secret, serializer: JSON)
    verifier.generate(value)
  end
end
