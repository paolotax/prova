require "test_helper"

class MandatiControllerTest < ActionDispatch::IntegrationTest
  fixtures :accounts, :users, :memberships, :editori, :mandati, :adozioni, :scuole, :classi

  setup do
    @account = accounts(:fizzy)
    @user = users(:one)
    sign_in_as(@user, @account)
  end

  test "should get index" do
    get mandati_path(account_id: @account.id)
    assert_response :success
  end

  test "index shows account mandati" do
    get mandati_path(account_id: @account.id)
    assert_response :success
    assert_match "Zanichelli", response.body
  end

  test "should get select_editori" do
    get select_editori_mandati_path(account_id: @account.id)
    assert_response :success
  end

  test "should create mandato for single editore" do
    # First destroy existing to avoid uniqueness conflict
    mandati(:fizzy_zanichelli).destroy
    mandati(:fizzy_mondadori).destroy

    # 2 zone attive (MI/E e MI/M) → 2 mandati creati
    assert_difference("Mandato.count", 2) do
      post mandati_path(account_id: @account.id),
        params: { hgruppo: "Zanichelli Group", heditore: editori(:zanichelli).id },
        as: :turbo_stream
    end
    assert_response :success
  end

  test "should create mandati for entire group" do
    mandati(:fizzy_zanichelli).destroy

    # 2 zone attive (MI/E e MI/M) → 2 mandati per editore (uno già esiste)
    assert_difference("Mandato.count", 2) do
      post mandati_path(account_id: @account.id),
        params: { hgruppo: "Zanichelli Group" },
        as: :turbo_stream
    end
  end

  test "should create disdetta on mandato" do
    mandato = mandati(:fizzy_zanichelli)
    assert_not mandato.disdetta?

    post mandato_disdetta_path(mandato_id: mandato.id, account_id: @account.id),
      as: :turbo_stream
    assert_response :success

    mandato.reload
    assert mandato.disdetta?
  end

  test "should destroy disdetta on mandato" do
    mandato = mandati(:fizzy_zanichelli)
    mandato.update!(disdetta: true)

    delete mandato_disdetta_path(mandato_id: mandato.id, account_id: @account.id),
      as: :turbo_stream
    assert_response :success

    mandato.reload
    assert_not mandato.disdetta?
  end

  test "should destroy mandato" do
    mandato = mandati(:fizzy_mondadori)
    assert_difference("Mandato.count", -1) do
      delete mandato_path(mandato, account_id: @account.id),
        as: :turbo_stream
    end
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
