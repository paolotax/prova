require "test_helper"

class PersoneControllerTest < ActionDispatch::IntegrationTest
  include ActionView::RecordIdentifier

  fixtures :accounts, :users, :memberships, :persone, :scuole

  setup do
    @account = accounts(:fizzy)
    @user = users(:one)
    @persona = persone(:persona_fizzy)

    sign_in_as(@user, @account)
  end

  test "index si intitola Contatti e mostra le card" do
    get persone_path(account_id: @account.id)

    assert_response :success
    assert_select "h1", /Contatti/i
    assert_select ".data-table__head", count: 0
  end

  test "index vista tabella mostra righe con scuola" do
    get persone_path(account_id: @account.id, vista: "tabella")

    assert_response :success
    assert_select ".data-table__head"
    assert_select "div##{dom_id(@persona)}.data-row"
    assert_match @persona.scuola.denominazione, response.body
  end

  test "righe tabella senza checkbox (niente bulk actions)" do
    get persone_path(account_id: @account.id, vista: "tabella")

    assert_select ".data-row__cell--check input", count: 0
  end

  test "sort per cognome e per comune della scuola" do
    get persone_path(account_id: @account.id, vista: "tabella", sort: "nome.asc")
    assert_response :success

    get persone_path(account_id: @account.id, vista: "tabella", sort: "comune.asc")
    assert_response :success
    assert_select "div##{dom_id(@persona)}.data-row"
  end

  test "tabella scopata sull'account corrente" do
    other = persone(:persona_acme)

    get persone_path(account_id: @account.id, vista: "tabella")

    assert_response :success
    assert_match @persona.cognome, response.body
    assert_no_match other.cognome, response.body
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
