# == Schema Information
#
# Table name: adozioni_comunicate
#
#  id                 :uuid             not null, primary key
#  alunni             :integer          not null
#  anno_corso         :string           not null
#  anno_scolastico    :string           not null
#  codicescuola       :string           not null
#  comune             :string
#  descrizione_scuola :string
#  ean                :string           not null
#  editore            :string
#  fonte              :string           default("excel"), not null
#  provincia          :string
#  sezioni            :string           default(""), not null
#  stato_match        :string           default("da_verificare"), not null
#  titolo             :string
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  account_id         :uuid             not null
#  adozione_id        :uuid
#  classe_id          :uuid
#  import_record_id   :uuid
#
# Indexes
#
#  index_adozioni_comunicate_on_account_id_and_stato_match  (account_id,stato_match)
#  index_adozioni_comunicate_on_adozione_id                 (adozione_id)
#  index_adozioni_comunicate_unicita                        (account_id,anno_scolastico,codicescuola,ean,anno_corso,sezioni) UNIQUE
#
require "test_helper"

class Adozioni::ComunicataTest < ActiveSupport::TestCase
  fixtures :accounts

  setup do
    @account = accounts(:fizzy)
    Current.account = @account
  end

  teardown { Current.reset }

  def valid_attrs(overrides = {})
    { account: @account, anno_scolastico: "202627", codicescuola: "REEE81001P",
      ean: "9788809917583", anno_corso: "3", sezioni: "B", alunni: 25,
      fonte: "excel" }.merge(overrides)
  end

  test "valida con attributi completi" do
    assert Adozioni::Comunicata.new(valid_attrs).valid?
  end

  test "richiede alunni positivo" do
    refute Adozioni::Comunicata.new(valid_attrs(alunni: 0)).valid?
  end

  test "rifiuta stato_match sconosciuto" do
    refute Adozioni::Comunicata.new(valid_attrs(stato_match: "boh")).valid?
  end

  test "unicita su chiave canonica" do
    Adozioni::Comunicata.create!(valid_attrs)
    assert_raises(ActiveRecord::RecordNotUnique) do
      Adozioni::Comunicata.new(valid_attrs(alunni: 99)).save(validate: false)
    end
  end

  test "normalizza_ean toglie trattini e spazi" do
    assert_equal "9788809917583", Adozioni::Comunicata.normalizza_ean("978-88-0991758 3")
  end

  test "sezioni_lista e multi_sezione?" do
    riga = Adozioni::Comunicata.new(valid_attrs(sezioni: "A, B,C"))
    assert_equal %w[A B C], riga.sezioni_lista
    assert riga.multi_sezione?
    refute Adozioni::Comunicata.new(valid_attrs(sezioni: "A")).multi_sezione?
  end
end
