require "test_helper"

class Accounts::Mandati::SincronizzazioneAdozioniControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  fixtures :accounts, :users, :memberships

  setup do
    @account = accounts(:fizzy)
    @user = users(:one)
    sign_in_as(@user, @account)
  end

  test "POST enqueues RebuildAccountAdozioniJob" do
    assert_enqueued_with(job: RebuildAccountAdozioniJob) do
      post accounts_mandati_sincronizzazione_adozioni_path(account_id: @account.id),
        as: :turbo_stream
    end
    assert_response :success
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
