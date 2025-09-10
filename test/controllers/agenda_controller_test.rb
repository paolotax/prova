require "test_helper"

class AgendaControllerTest < ActionDispatch::IntegrationTest
  test "should get show" do
    get agenda_show_url
    assert_response :success
  end

  test "should get adozioni_tappe_pdf" do
    user = users(:one) # Assumes you have a user fixture
    sign_in user
    
    get adozioni_tappe_pdf_path(giorno: Date.today), as: :pdf
    assert_response :success
    assert_equal 'application/pdf', response.content_type
  end

  test "should get tappe_giorno_pdf" do
    user = users(:one) # Assumes you have a user fixture
    sign_in user
    
    get tappe_giorno_pdf_path(giorno: Date.today), as: :pdf
    assert_response :success
    assert_equal 'application/pdf', response.content_type
  end

  test "should get dettaglio_appunti_documenti_pdf" do
    user = users(:one) # Assumes you have a user fixture
    sign_in user
    
    get dettaglio_appunti_documenti_pdf_path(giorno: Date.today), as: :pdf
    assert_response :success
    assert_equal 'application/pdf', response.content_type
  end

  test "should get fogli_scuola_tappe_pdf with mie_adozioni" do
    user = users(:one) # Assumes you have a user fixture
    sign_in user
    
    get fogli_scuola_tappe_pdf_path(giorno: Date.today, tipo_stampa: 'mie_adozioni'), as: :pdf
    assert_response :success
    assert_equal 'application/pdf', response.content_type
  end

  test "should get fogli_scuola_tappe_pdf with sovrapacchi" do
    user = users(:one) # Assumes you have a user fixture
    sign_in user
    
    get fogli_scuola_tappe_pdf_path(giorno: Date.today, tipo_stampa: 'mie_adozioni', con_sovrapacchi: true), as: :pdf
    assert_response :success
    assert_equal 'application/pdf', response.content_type
  end
end
