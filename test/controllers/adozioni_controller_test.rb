require "test_helper"

class AdozioniControllerTest < ActionDispatch::IntegrationTest
  setup do
    @adozione = adozioni(:one)
  end

  test "should get index" do
    get adozioni_url
    assert_response :success
  end

  test "should get new" do
    get new_adozione_url
    assert_response :success
  end

  test "should create adozione" do
    assert_difference("Adozione.count") do
      post adozioni_url, params: { adozione: { import_adozione_id: @adozione.import_adozione_id, libro_id: @adozione.libro_id, note: @adozione.note, numero_sezioni: @adozione.numero_sezioni, team: @adozione.team, user_id: @adozione.user_id } }
    end

    assert_redirected_to adozione_url(Adozione.last)
  end

  test "should show adozione" do
    get adozione_url(@adozione)
    assert_response :success
  end

  test "should get edit" do
    get edit_adozione_url(@adozione)
    assert_response :success
  end

  test "should update adozione" do
    patch adozione_url(@adozione), params: { adozione: { import_adozione_id: @adozione.import_adozione_id, libro_id: @adozione.libro_id, note: @adozione.note, numero_sezioni: @adozione.numero_sezioni, team: @adozione.team, user_id: @adozione.user_id } }
    assert_redirected_to adozione_url(@adozione)
  end

  test "should destroy adozione" do
    assert_difference("Adozione.count", -1) do
      delete adozione_url(@adozione)
    end

    assert_redirected_to adozioni_url
  end
end
