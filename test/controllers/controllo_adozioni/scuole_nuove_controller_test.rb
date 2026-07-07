require "test_helper"

class ControlloAdozioni::ScuoleNuoveControllerTest < ActionDispatch::IntegrationTest
  fixtures :accounts, :users, :memberships

  setup do
    @account = accounts(:fizzy)
    sign_in_as(users(:one), @account)
  end

  test "create accoda il fan-out per l'admin, scoped alla provincia" do
    assert_enqueued_with(job: AggiungiScuoleNuoveJob,
                         args: [@account, { provincia: "MI" }]) do
      post controllo_adozioni_scuole_nuove_path(account_id: @account.id, provincia: "MI")
    end
    assert_redirected_to controllo_adozioni_index_path(account_id: @account.id, provincia: "MI")
  end

  test "create senza provincia accoda account-wide" do
    assert_enqueued_with(job: AggiungiScuoleNuoveJob,
                         args: [@account, { provincia: nil }]) do
      post controllo_adozioni_scuole_nuove_path(account_id: @account.id)
    end
  end

  test "create con codice accoda l'aggiunta della singola scuola" do
    assert_enqueued_with(job: AggiungiScuoleNuoveJob,
                         args: [@account, { provincia: "MI", codici: ["MIEE12345"] }]) do
      post controllo_adozioni_scuole_nuove_path(account_id: @account.id, provincia: "MI", codice: "MIEE12345")
    end
    assert_redirected_to controllo_adozioni_index_path(account_id: @account.id, provincia: "MI")
  end

  test "create vietata ai member" do
    sign_in_as(users(:two), @account)
    assert_no_enqueued_jobs only: AggiungiScuoleNuoveJob do
      post controllo_adozioni_scuole_nuove_path(account_id: @account.id)
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
