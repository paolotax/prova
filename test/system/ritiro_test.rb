require "application_system_test_case"

# System test del flusso ritiro (scuola -> bulk select -> genera documento).
#
# Skippato di default perche` il container `prova-app-1` non include Chrome /
# chromedriver. Per eseguirlo:
#   1. Aggiungere `chromium` + `chromium-driver` al Dockerfile, OPPURE
#   2. Lanciare i system test fuori dal container (host con bin/dev attivo)
# poi rimuovere `skip` qui sotto.
class RitiroTest < ApplicationSystemTestCase
  fixtures :accounts, :users, :memberships, :editori, :categorie, :libri, :scuole,
           :collane, :bolle_visione, :bolla_visione_righe, :causali

  setup do
    skip "Selenium/Chrome non disponibile nel container; vedi commento in alto"

    @account = accounts(:fizzy)
    @user = users(:one)
    @scuola = scuole(:scuola_fizzy)

    session = @user.sessions.create!(account: @account)
    page.driver.browser.manage.add_cookie(name: "session_token", value: sign_cookie(session.token))
  end

  test "flusso completo: scuola -> ritiro -> seleziona righe -> genera Scarico Saggi" do
    visit scuola_path(@scuola, account_id: @account.id)
    click_on "Ritiro", match: :first

    assert_text "BV-"

    all("input[type=checkbox][name='bolla_visione_riga_ids[]']").first(2).each(&:click)

    click_on "Scarico Saggi"
    click_on "Crea documento"

    assert_text "Documento Scarico saggi creato"
  end

  test "rientro one-click rimuove la riga dalla lista" do
    visit scuola_ritiro_path(@scuola, account_id: @account.id)
    riga = bolla_visione_righe(:aperta)

    within "[data-bolla-visione-riga-id='#{riga.id}']" do
      click_button "Rientro"
    end

    assert_no_selector "[data-bolla-visione-riga-id='#{riga.id}']"
  end

  private

  def sign_cookie(value)
    key_generator = Rails.application.key_generator
    secret = key_generator.generate_key("signed cookie")
    verifier = ActiveSupport::MessageVerifier.new(secret, serializer: JSON)
    verifier.generate(value)
  end
end
