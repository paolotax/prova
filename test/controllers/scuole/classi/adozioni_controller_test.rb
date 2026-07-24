require "test_helper"

class Scuole::Classi::AdozioniControllerTest < ActionDispatch::IntegrationTest
  fixtures :accounts, :users, :memberships, :scuole, :classi, :adozioni, :libri, :editori, :categorie

  setup do
    @account = accounts(:fizzy)
    @user = users(:one)
    @scuola = scuole(:primaria_attiva)
    @classe = classi(:pa_1a) # classe del path (placeholder del bottone)

    sign_in_as(@user, @account)

    # Due esemplari nel catalogo adozioni dell'account (anno di corso 1, 202526).
    # Fanno da SORGENTE dello snapshot: titolo/editore/isbn vengono da qui, MAI da Libro.
    @es1 = Adozione.create!(
      account: @account, classe: classi(:pa_1a),
      codice_isbn: "9788899000001", titolo: "Sussidiario Catalogo", editore: "CatalogoEd",
      autori: "Cat Autore", disciplina: "Sussidiario", prezzo_cents: 2000,
      anno_corso: "1", anno_scolastico: "202526", da_acquistare: true
    )
    @es2 = Adozione.create!(
      account: @account, classe: classi(:pa_1a),
      codice_isbn: "9788899000002", titolo: "Religione Catalogo", editore: "CatalogoEd2",
      autori: "Cat Autore2", disciplina: "Religione", prezzo_cents: 1000,
      anno_corso: "1", anno_scolastico: "202526", da_acquistare: true
    )

    # Un Libro dell'account con lo STESSO isbn dell'esemplare ma titolo DIVERSO:
    # serve a dimostrare che lo snapshot prende il titolo dall'esemplare (adozione)
    # e non dal catalogo Libro, pur agganciando libro_id per isbn.
    @libro_omonimo = Libro.create!(
      account: @account, user: @user, editore: editori(:mondadori), categoria: categorie(:ministeriali),
      titolo: "TITOLO LIBRO DIVERSO", codice_isbn: "9788899000001", prezzo_in_cents: 9999
    )
  end

  test "should get new" do
    get new_scuola_classe_adozione_path(@scuola, @classe, account_id: @account.id)

    assert_response :success
    assert_match(/Aggiungi adozioni/i, response.body)
  end

  test "bulk crea il prodotto cartesiano classi x esemplari con snapshot dall'adozione" do
    classe_a = classi(:pa_2a)
    classe_b = classi(:pa_3a)

    assert_difference("Adozione.count", 4) do
      post scuola_classe_adozioni_path(@scuola, @classe, account_id: @account.id), params: {
        classe_ids: "#{classe_a.id},#{classe_b.id}",
        adozione_ids: "#{@es1.id},#{@es2.id}",
        da_acquistare: "1"
      }
    end

    riga = classe_a.adozioni.find_by(codice_isbn: @es1.codice_isbn)
    assert_not_nil riga
    # Snapshot dall'ESEMPLARE, non dal Libro omonimo.
    assert_equal "Sussidiario Catalogo", riga.titolo
    refute_equal @libro_omonimo.titolo, riga.titolo
    assert_equal "CatalogoEd", riga.editore
    assert_equal "Cat Autore", riga.autori
    assert_equal "Sussidiario", riga.disciplina
    assert_equal 2000, riga.prezzo_cents
    # libro_id agganciato per isbn (concorrenza -> nil), qui esiste il libro omonimo.
    assert_equal @libro_omonimo.id, riga.libro_id
    # anno_scolastico/anno_corso dalla classe TARGET, non dall'esemplare.
    assert_equal classe_a.anno_scolastico, riga.anno_scolastico
    assert_equal classe_a.anno_corso, riga.anno_corso
    assert_equal @scuola.codice_ministeriale, riga.codicescuola
    assert_not riga.riportata?
    assert riga.da_acquistare?
  end

  test "esemplare senza libro omonimo lascia libro_id nil (concorrenza)" do
    classe_a = classi(:pa_2a)

    post scuola_classe_adozioni_path(@scuola, @classe, account_id: @account.id), params: {
      classe_ids: classe_a.id.to_s,
      adozione_ids: @es2.id.to_s,
      da_acquistare: "1"
    }

    riga = classe_a.adozioni.find_by(codice_isbn: @es2.codice_isbn)
    assert_not_nil riga
    assert_nil riga.libro_id
  end

  test "i duplicati (stessa classe+isbn+anno) sono saltati e contati" do
    classe_a = classi(:pa_2a)

    post scuola_classe_adozioni_path(@scuola, @classe, account_id: @account.id), params: {
      classe_ids: classe_a.id.to_s,
      adozione_ids: "#{@es1.id},#{@es2.id}",
      da_acquistare: "1"
    }

    assert_no_difference("Adozione.count") do
      post scuola_classe_adozioni_path(@scuola, @classe, account_id: @account.id),
        as: :turbo_stream,
        params: {
          classe_ids: classe_a.id.to_s,
          adozione_ids: "#{@es1.id},#{@es2.id}",
          da_acquistare: "1"
        }
    end

    assert_response :success
    assert_match(/gi\S* presenti/i, response.body)
  end

  test "flag checkbox: da_acquistare non spuntato salva false" do
    classe_a = classi(:pa_2a)

    post scuola_classe_adozioni_path(@scuola, @classe, account_id: @account.id), params: {
      classe_ids: classe_a.id.to_s,
      adozione_ids: @es1.id.to_s
    }

    riga = classe_a.adozioni.find_by(codice_isbn: @es1.codice_isbn)
    assert_not riga.da_acquistare?
  end

  test "create in turbo_stream: flash, chiusura modal e reload del frame con le nuove righe" do
    classe_a = classi(:pa_2a)

    post scuola_classe_adozioni_path(@scuola, @classe, account_id: @account.id),
      as: :turbo_stream,
      params: {
        classe_ids: classe_a.id.to_s,
        adozione_ids: @es1.id.to_s,
        da_acquistare: "1"
      }

    assert_response :success
    assert_match "scuola_adozioni", response.body
    assert_match "turbo-stream", response.body
    # Il frame arriva già renderizzato (scope tutte): la riga aggiunta è nel body.
    assert_match "Sussidiario Catalogo", response.body
  end

  test "ricalcolo contatori accodato in background (il submit non blocca)" do
    classe_a = classi(:pa_2a)

    assert_enqueued_with(job: UpdateScuolaMieAdozioniJob) do
      post scuola_classe_adozioni_path(@scuola, @classe, account_id: @account.id), params: {
        classe_ids: classe_a.id.to_s,
        adozione_ids: "#{@es1.id},#{@es2.id}",
        da_acquistare: "1"
      }
    end
  end

  test "classe di un'altra scuola nel body: esclusa" do
    estranea = classi(:prima_a_fizzy) # altra scuola (scuola_fizzy), stesso account
    valida = classi(:pa_2a)

    assert_difference("Adozione.count", 1) do
      post scuola_classe_adozioni_path(@scuola, @classe, account_id: @account.id), params: {
        classe_ids: "#{valida.id},#{estranea.id}",
        adozione_ids: @es1.id.to_s,
        da_acquistare: "1"
      }
    end

    assert_nil estranea.adozioni.find_by(codice_isbn: @es1.codice_isbn)
    assert_not_nil valida.adozioni.find_by(codice_isbn: @es1.codice_isbn)
  end

  test "esemplare di un altro account: ignorato, niente righe, 422" do
    estranea = adozioni(:adozione_fisica_acme)
    classe_a = classi(:pa_2a)

    assert_no_difference("Adozione.count") do
      post scuola_classe_adozioni_path(@scuola, @classe, account_id: @account.id), params: {
        classe_ids: classe_a.id.to_s,
        adozione_ids: estranea.id.to_s,
        da_acquistare: "1"
      }
    end

    assert_response :unprocessable_entity
  end

  test "selezioni vuote: 422" do
    assert_no_difference("Adozione.count") do
      post scuola_classe_adozioni_path(@scuola, @classe, account_id: @account.id), params: {
        classe_ids: "",
        adozione_ids: ""
      }
    end

    assert_response :unprocessable_entity
  end

  test "new con fissa: classe fissata, niente multiselect classi" do
    get new_scuola_classe_adozione_path(@scuola, @classe, account_id: @account.id, fissa: 1)

    assert_response :success
    assert_match "Aggiungi adozioni in #{@classe.nome_breve}", response.body
    assert_match %(name="classe_ids" id="classe_ids" value="#{@classe.id}"), response.body
    assert_no_match(/Seleziona classi/, response.body)
  end

  test "create con fissa in turbo_stream aggiorna tabella e meta della classe" do
    post scuola_classe_adozioni_path(@scuola, @classe, account_id: @account.id),
      as: :turbo_stream,
      params: {
        fissa: "1",
        classe_ids: @classe.id.to_s,
        adozione_ids: @es1.id.to_s,
        da_acquistare: "1"
      }

    assert_response :success
    assert_match ActionView::RecordIdentifier.dom_id(@classe, :adozioni), response.body
    assert_match ActionView::RecordIdentifier.dom_id(@classe, :meta), response.body
  end

  test "destroy elimina l'adozione della classe e accoda il ricalcolo" do
    assert_difference("Adozione.count", -1) do
      assert_enqueued_with(job: UpdateScuolaMieAdozioniJob) do
        delete scuola_classe_adozione_path(@scuola, classi(:pa_1a), @es1, account_id: @account.id)
      end
    end

    assert_redirected_to scuola_classe_path(@scuola, classi(:pa_1a))
    assert_nil Adozione.find_by(id: @es1.id)
  end

  test "destroy in turbo_stream rimuove tile e rirenderizza la sezione adozioni" do
    delete scuola_classe_adozione_path(@scuola, classi(:pa_1a), @es1, account_id: @account.id),
           as: :turbo_stream

    assert_response :success
    assert_match "turbo-stream", response.body
    assert_match ActionView::RecordIdentifier.dom_id(classi(:pa_1a), :adozioni), response.body
    # La sezione rirenderizzata non contiene più il titolo eliminato
    # (il flash lo contiene nel messaggio: ancorarsi al replace della sezione).
    sezione_replace = response.body[/action="replace" target="adozioni_.*\z/m].to_s
    assert_no_match(/#{Regexp.escape(@es1.titolo)}/, sezione_replace)
    assert_nil Adozione.find_by(id: @es1.id)
  end

  test "destroy di un'adozione di un'altra classe: 404" do
    assert_no_difference("Adozione.count") do
      delete scuola_classe_adozione_path(@scuola, classi(:pa_2a), @es1, account_id: @account.id)
    end

    assert_response :not_found
  end

  test "non si crea su scuola di un altro account" do
    other_scuola = scuole(:scuola_acme)
    other_classe = classi(:prima_a_acme)

    assert_no_difference("Adozione.count") do
      post scuola_classe_adozioni_path(other_scuola, other_classe, account_id: @account.id), params: {
        classe_ids: other_classe.id.to_s,
        adozione_ids: @es1.id.to_s
      }
    end

    assert_response :not_found
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
