require "test_helper"

class LegalControllerTest < ActionDispatch::IntegrationTest
  test "privacy is public and identifies the controller" do
    get privacy_path

    assert_response :success
    assert_select "h1", "Informativa sulla privacy"
    assert_select "body", text: /Paolo Tassinari/
    assert_select "a[href='mailto:p.tassinari@pec.it']"
  end

  test "data sources is public and attributes the ministry and IODL" do
    get data_sources_path

    assert_response :success
    assert_select "h1", "Fonti e licenze dei dati"
    assert_select "body", text: /Ministero dell'Istruzione e del Merito/
    assert_select "body", text: /IODL 2\.0/
    assert_select "body", text: /non è affiliato, sponsorizzato o approvato/
  end
end
