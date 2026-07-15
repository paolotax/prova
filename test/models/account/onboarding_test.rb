require "test_helper"

class Account::OnboardingTest < ActiveSupport::TestCase
  fixtures :accounts, :users, :memberships

  AZIENDA_ATTRS = {
    ragione_sociale: "Test SRL", partita_iva: "11111111111",
    codice_fiscale: "TSTCMP00A01H501A", regime_fiscale: "rf19", indirizzo: "Via Test 1",
    cap: "00100", comune: "Roma", provincia: "RM", nazione: "IT", email: "test@test.it",
    telefono: "+39 06 1111111", indirizzo_telematico: "TEST123",
    iban: "IT60X0542811101000000111111", banca: "Test Bank"
  }.freeze

  setup do
    @account = Account.create!(name: "Nuovo")
    @onboarding = Account::Onboarding.new(@account)
  end

  test "step azienda quando mancano i dati aziendali" do
    assert_equal :azienda, @onboarding.step
    assert @onboarding.da_completare?
    assert @onboarding.da_iniziare?
  end

  test "step zone quando c'e' l'azienda ma nessuna zona" do
    @account.create_azienda!(**AZIENDA_ATTRS)
    assert_equal :zone, @onboarding.step
    assert_not @onboarding.da_iniziare?
  end

  test "step importazione quando le zone non sono tutte attive" do
    @account.create_azienda!(**AZIENDA_ATTRS)
    @account.zone.create!(provincia: "XX", grado: "E", stato: "pronta")
    assert_equal :importazione, @onboarding.step
  end

  test "step mandati a zone attive senza mandati" do
    @account.create_azienda!(**AZIENDA_ATTRS)
    @account.zone.create!(provincia: "XX", grado: "E", stato: "attiva")
    assert_equal :mandati, @onboarding.step
  end

  test "fine quando c'e' almeno un mandato" do
    @account.create_azienda!(**AZIENDA_ATTRS)
    @account.zone.create!(provincia: "XX", grado: "E", stato: "attiva")
    editore = Editore.create!(editore: "EDITORE ONB")
    @account.mandati.create!(editore: editore, provincia: "XX", grado: "E")

    assert_equal :fine, @onboarding.step
    assert_not @onboarding.da_completare?
  end
end
