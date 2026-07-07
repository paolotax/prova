require "test_helper"

class ControlloAdozioni::PromozioniMassiveControllerTest < ActionDispatch::IntegrationTest
  fixtures :accounts, :users, :memberships

  setup do
    @account = accounts(:fizzy)
    sign_in_as(users(:one), @account)
  end

  test "create accoda il fan-out per l'admin, scoped alla provincia" do
    assert_enqueued_with(job: PromuoviScuolePromuovibiliJob,
                         args: [@account, { provincia: "MI" }]) do
      post controllo_adozioni_promozioni_massive_path(account_id: @account.id, provincia: "MI")
    end
    assert_redirected_to controllo_adozioni_index_path(account_id: @account.id, provincia: "MI")
  end

  test "create senza provincia accoda account-wide" do
    assert_enqueued_with(job: PromuoviScuolePromuovibiliJob,
                         args: [@account, { provincia: nil }]) do
      post controllo_adozioni_promozioni_massive_path(account_id: @account.id)
    end
  end

  test "create vietata ai member" do
    sign_in_as(users(:two), @account)
    assert_no_enqueued_jobs only: PromuoviScuolePromuovibiliJob do
      post controllo_adozioni_promozioni_massive_path(account_id: @account.id)
    end
    assert_response :forbidden
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
