require "test_helper"

class ConfezioneControllerTest < ActionDispatch::IntegrationTest
  test "should get show" do
    get confezione_show_url
    assert_response :success
  end

  test "should get aggiungi" do
    get confezione_aggiungi_url
    assert_response :success
  end

  test "should get elimina" do
    get confezione_elimina_url
    assert_response :success
  end
end
