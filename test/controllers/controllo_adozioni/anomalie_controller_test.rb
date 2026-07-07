require "test_helper"

class ControlloAdozioni::AnomalieControllerTest < ActionDispatch::IntegrationTest
  fixtures :accounts, :users, :memberships

  setup do
    @account = accounts(:fizzy)
    sign_in_as(users(:one), @account)
  end

  test "create accoda il ricalcolo globale per l'admin" do
    assert_enqueued_with(job: RicalcolaAnomalieJob) do
      post controllo_adozioni_anomalie_path(account_id: @account.id)
    end
    assert_redirected_to controllo_adozioni_index_path(account_id: @account.id)
  end

  test "create ignora la provincia (ricalcolo sempre globale)" do
    assert_enqueued_with(job: RicalcolaAnomalieJob) do
      post controllo_adozioni_anomalie_path(account_id: @account.id, provincia: "MI")
    end
    assert_redirected_to controllo_adozioni_index_path(account_id: @account.id)
  end

  test "create vietata ai member" do
    sign_in_as(users(:two), @account)
    assert_no_enqueued_jobs only: RicalcolaAnomalieJob do
      post controllo_adozioni_anomalie_path(account_id: @account.id)
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
