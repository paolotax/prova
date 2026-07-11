require "test_helper"

class Appunti::AttachmentsControllerTest < ActionDispatch::IntegrationTest
  fixtures :accounts, :users, :memberships

  setup do
    @account = accounts(:fizzy)
    @user = users(:one)
    sign_in_as(@user, @account)
  end

  test "can remove an attachment from an appunto in the current account" do
    appunto = create_appunto(@account, @user)
    appunto.attachments.attach(io: StringIO.new("mine"), filename: "mine.txt")
    attachment = appunto.attachments.first

    delete appunto_attachment_path(account_id: @account.id, appunto_id: appunto.id, id: attachment.id)

    assert_response :redirect
  end

  test "cannot remove an attachment from another account" do
    other_account = accounts(:acme)
    other_user = users(:multi_account)
    appunto = create_appunto(other_account, other_user)
    appunto.attachments.attach(io: StringIO.new("private"), filename: "private.txt")
    attachment = appunto.attachments.first

    delete appunto_attachment_path(account_id: @account.id, appunto_id: appunto.id, id: attachment.id)

    assert_response :not_found
    assert ActiveStorage::Attachment.exists?(attachment.id)
  end

  private

    def create_appunto(account, user)
      Appunto.create!(account: account, user: user, nome: "Test allegato")
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
      ActiveSupport::MessageVerifier.new(secret, serializer: JSON).generate(value)
    end
end
