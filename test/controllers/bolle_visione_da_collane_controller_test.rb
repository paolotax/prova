require "test_helper"

class BolleVisioneDaCollaneControllerTest < ActionDispatch::IntegrationTest
  fixtures :accounts, :users, :memberships, :editori, :categorie, :libri, :scuole,
           :collane

  setup do
    @account = accounts(:fizzy)
    @user = users(:one)
    @scuola = scuole(:scuola_fizzy)
    sign_in_as(@user, @account)
  end

  test "create genera N BollaVisione da N collane selezionate" do
    collana = collane(:collana_fizzy)

    assert_difference -> { BollaVisione.count } => 1 do
      post scuola_ritiro_bolle_da_collane_path(@scuola, account_id: @account.id), params: {
        collana_ids: [collana.id]
      }
    end
    assert_redirected_to scuola_ritiro_path(@scuola, account_id: @account.id)
  end

  test "create senza collana_ids torna in show con flash" do
    post scuola_ritiro_bolle_da_collane_path(@scuola, account_id: @account.id), params: {
      collana_ids: []
    }
    assert_redirected_to scuola_ritiro_path(@scuola, account_id: @account.id)
    assert_match(/seleziona/i, flash[:alert])
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
