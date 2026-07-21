# frozen_string_literal: true

require "test_helper"

class ImportsControllerTest < ActionDispatch::IntegrationTest
  fixtures :users, :accounts, :memberships, :clienti, :causali

  setup do
    @user = users(:one)
    @account = accounts(:fizzy)
    sign_in_as(@user, @account)

    @documento = Documento.create!(
      account: @account, user: @user, causale: causali(:campionario),
      clientable: clienti(:cliente_fizzy), numero_documento: 9001,
      data_documento: Date.current
    )
  end

  test "il form excel posta documento_id dentro metadata" do
    get new_import_path(account_id: @account.id, type: "documenti", subtype: "excel")

    assert_response :success
    # Il nome deve combaciare con permit(metadata: {}): un name annidato male
    # (import_record[import_record[...]]) viene scartato e il processor
    # esplode con Documento.find(nil).
    assert_select "select[name='import_record[metadata][documento_id]']"
    assert_select "input[type=hidden][name='import_record[metadata][format]'][value=excel]"
  end

  test "create salva documento_id nel metadata dell'import" do
    file = fixture_file_upload("documento_righe.csv", "text/csv")

    assert_difference "ImportRecord.count", 1 do
      post imports_path(account_id: @account.id), params: {
        import_record: {
          import_type: "documenti",
          file: file,
          metadata: { format: "excel", documento_id: @documento.id }
        }
      }
    end

    import = ImportRecord.last
    assert_equal @documento.id.to_s, import.metadata["documento_id"].to_s
    assert_equal "excel", import.metadata["format"]
  end

  private

    def sign_in_as(user, account)
      session = user.sessions.create!(account: account)
      cookies[:session_token] = sign_cookie(session.token)
      Current.user = user
      Current.account = account
      Current.membership = user.memberships.find_by(account: account)
    end

    def sign_cookie(value)
      secret = Rails.application.key_generator.generate_key("signed cookie")
      ActiveSupport::MessageVerifier.new(secret, serializer: JSON).generate(value)
    end
end
