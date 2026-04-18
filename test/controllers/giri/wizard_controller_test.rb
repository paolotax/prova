require "test_helper"

class Giri::WizardControllerTest < ActionDispatch::IntegrationTest
  fixtures :accounts, :users, :memberships, :scuole, :classi, :libri, :editori, :categorie

  setup do
    @account = accounts(:fizzy)
    @user = users(:one)
    @scuola = scuole(:scuola_fizzy)
    @classe = classi(:prima_a_fizzy)
    @libro = libri(:libro_fizzy)
    sign_in_as(@user, @account)
  end

  test "GET wizard shows step 1" do
    get wizard_giri_path(account_id: @account.id)
    assert_response :success
    assert_select ".wizard__option", minimum: 5
  end

  test "GET wizard/scuole returns scuole for visite tipo" do
    get wizard_scuole_giri_path(account_id: @account.id, tipo_giro: "visite")
    assert_response :success
  end

  test "GET wizard/libri returns adopted libri for kit_adozioni" do
    crea_mia_adozione(classe: @classe, libro: @libro)

    get wizard_libri_giri_path(account_id: @account.id, tipo_giro: "kit_adozioni")

    assert_response :success
    gerarchia = @controller.instance_variable_get(:@libri_gerarchia)
    assert_kind_of Hash, gerarchia
    assert_includes gerarchia.values.flat_map(&:values).flatten, @libro
  end

  test "GET wizard/scuole with libro_ids filters to matching schools" do
    crea_mia_adozione(classe: @classe, libro: @libro)

    get wizard_scuole_giri_path(
      account_id: @account.id,
      tipo_giro: "kit_adozioni",
      libro_ids: [@libro.id]
    )

    assert_response :success
    gerarchia = @controller.instance_variable_get(:@gerarchia)
    nomi = gerarchia.values.flat_map { |aree| aree.values.flat_map { |dir| dir.values.flatten } }.map(&:denominazione)
    assert_includes nomi, @scuola.denominazione
  end

  test "GET wizard/riepilogo lists selected libri with adozioni count" do
    crea_mia_adozione(classe: @classe, libro: @libro)

    get wizard_riepilogo_giri_path(
      account_id: @account.id,
      tipo_giro: "kit_adozioni",
      titolo: "Test Kit",
      libro_ids: [@libro.id],
      school_ids: [@scuola.id],
      scuole_count: 1,
      libri_count: 1
    )

    assert_response :success
    riepilogo = @controller.instance_variable_get(:@libri_riepilogo)
    assert_equal 1, riepilogo.size
    libro, conteggio = riepilogo.first
    assert_equal @libro.id, libro.id
    assert_equal 1, conteggio
  end

  test "POST wizard creates giro with tappe" do
    assert_difference "Giro.count", 1 do
      post create_wizard_giri_path(account_id: @account.id), params: {
        tipo_giro: "visite",
        titolo: "Test Visite",
        school_ids: [@scuola.id]
      }
    end

    giro = Giro.last
    assert_equal "visite", giro.tipo_giro
    assert_equal "Test Visite", giro.titolo
    assert_equal 1, giro.tappe.count
    assert_redirected_to giro_path(giro, account_id: @account.id)
  end

  test "POST wizard for kit_adozioni writes detailed descrizione on tappa" do
    crea_mia_adozione(classe: @classe, libro: @libro)

    post create_wizard_giri_path(account_id: @account.id), params: {
      tipo_giro: "kit_adozioni",
      titolo: "Test Kit",
      school_ids: [@scuola.id],
      libro_ids: [@libro.id]
    }

    giro = Giro.last
    tappa = giro.tappe.first
    assert_includes tappa.descrizione, @libro.titolo.upcase
    assert_includes tappa.descrizione, "#{@classe.anno_corso}#{@classe.sezione} -"
    assert_equal({ libro_ids: [@libro.id.to_s] }, giro.conditions)
  end

  test "POST wizard for kit_adozioni skips annotation when scuola has no matching libro" do
    # Scuola senza adozioni mie — nessun libro in comune, nessuna annotazione.
    post create_wizard_giri_path(account_id: @account.id), params: {
      tipo_giro: "kit_adozioni",
      titolo: "Test Kit",
      school_ids: [@scuola.id],
      libro_ids: [@libro.id]
    }

    giro = Giro.last
    tappa = giro.tappe.first
    assert_nil tappa.descrizione
  end

  private

  def crea_mia_adozione(classe:, libro:)
    Adozione.create!(
      account: @account,
      classe: classe,
      libro: libro,
      codice_isbn: libro.codice_isbn,
      titolo: libro.titolo,
      disciplina: libro.disciplina,
      mia: true,
      disdetta: false
    )
  end

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
