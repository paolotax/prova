# == Schema Information
#
# Table name: aziende
#
#  id                    :bigint           not null, primary key
#  banca                 :string
#  cap                   :string(5)        not null
#  codice_fiscale        :string(16)       not null
#  comune                :string           not null
#  email                 :string           not null
#  iban                  :string(27)
#  indirizzo             :string           not null
#  indirizzo_telematico  :string(7)
#  nazione               :string(2)        default("IT"), not null
#  partita_iva           :string(11)       not null
#  provincia             :string(2)        not null
#  ragione_sociale       :string           not null
#  regime_fiscale        :string           default(NULL), not null
#  sconto_defiscalizzato :boolean          default(FALSE), not null
#  telefono              :string
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  account_id            :uuid             not null
#  user_id               :bigint
#
# Indexes
#
#  index_aziende_on_account_id                     (account_id) UNIQUE
#  index_aziende_on_account_id_and_codice_fiscale  (account_id,codice_fiscale) UNIQUE
#  index_aziende_on_account_id_and_partita_iva     (account_id,partita_iva) UNIQUE
#  index_aziende_on_user_id                        (user_id)
#
require "test_helper"

class AziendaTest < ActiveSupport::TestCase
  fixtures :users, :accounts, :aziende, :memberships

  setup do
    @azienda = aziende(:fizzy_azienda)
    @account = accounts(:fizzy)
  end

  # Associations
  test "belongs to account" do
    assert_equal @account, @azienda.account
  end

  test "account has one azienda" do
    assert_equal @azienda, @account.azienda
  end

  # Validations
  test "valid azienda" do
    assert @azienda.valid?
  end

  test "requires account_id" do
    @azienda.account_id = nil
    assert_not @azienda.valid?
    assert @azienda.errors[:account_id].any?
  end

  test "account_id must be unique" do
    duplicate = Azienda.new(
      account: @account,
      partita_iva: "99999999999",
      codice_fiscale: "XXXXXX00X00X000X",
      ragione_sociale: "Duplicate SRL",
      regime_fiscale: :rf19,
      indirizzo: "Via Test 1",
      cap: "00100",
      comune: "Roma",
      provincia: "RM",
      nazione: "IT",
      email: "test@test.it",
      telefono: "+39 06 0000000",
      indirizzo_telematico: "0000000",
      iban: "IT60X0542811101000000000000",
      banca: "Test Bank"
    )
    assert_not duplicate.valid?
    assert duplicate.errors[:account_id].any?
  end

  test "requires partita_iva" do
    @azienda.partita_iva = nil
    assert_not @azienda.valid?
    assert @azienda.errors[:partita_iva].any?
  end

  test "partita_iva must be 11 characters" do
    @azienda.partita_iva = "123"
    assert_not @azienda.valid?
    assert @azienda.errors[:partita_iva].any?
  end

  test "requires codice_fiscale" do
    @azienda.codice_fiscale = nil
    assert_not @azienda.valid?
    assert @azienda.errors[:codice_fiscale].any?
  end

  test "codice_fiscale must be 16 characters" do
    @azienda.codice_fiscale = "ABC"
    assert_not @azienda.valid?
    assert @azienda.errors[:codice_fiscale].any?
  end

  test "requires ragione_sociale" do
    @azienda.ragione_sociale = nil
    assert_not @azienda.valid?
    assert @azienda.errors[:ragione_sociale].any?
  end

  test "requires regime_fiscale" do
    @azienda.regime_fiscale = nil
    assert_not @azienda.valid?
    assert @azienda.errors[:regime_fiscale].any?
  end

  # Enum
  test "regime_fiscale enum" do
    @azienda.regime_fiscale = :rf01
    assert @azienda.rf01?

    @azienda.regime_fiscale = :rf19
    assert @azienda.rf19?
  end

  # Computed attributes
  test "codice_destinatario returns indirizzo_telematico" do
    assert_equal @azienda.indirizzo_telematico, @azienda.codice_destinatario
  end
end
