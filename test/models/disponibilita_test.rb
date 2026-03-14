# == Schema Information
#
# Table name: disponibilita
#
#  id               :uuid             not null, primary key
#  data             :date
#  giorno_settimana :integer
#  ora_fine         :time
#  ora_inizio       :time
#  ricorrente       :boolean          default(FALSE)
#  tipo             :string           not null
#  titolo           :string
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  account_id       :uuid             not null
#  scuola_id        :uuid             not null
#  user_id          :bigint
#
# Indexes
#
#  idx_disponibilita_scuola_tipo_giorno       (scuola_id,tipo,giorno_settimana)
#  index_disponibilita_on_account_id          (account_id)
#  index_disponibilita_on_scuola_id           (scuola_id)
#  index_disponibilita_on_scuola_id_and_tipo  (scuola_id,tipo)
#  index_disponibilita_on_user_id             (user_id)
#
require "test_helper"

class DisponibilitaTest < ActiveSupport::TestCase
  fixtures :accounts, :scuole

  setup do
    @scuola = scuole(:scuola_fizzy)
  end

  test "creates orario with required fields" do
    d = @scuola.disponibilita.create!(
      tipo: "orario",
      giorno_settimana: 1,
      ora_inizio: "08:00",
      ora_fine: "13:00",
      account: @scuola.account
    )
    assert d.persisted?
    assert_equal "08:00-13:00", d.orario_label
    assert_equal "Lunedì", d.giorno_label
  end

  test "orario requires giorno_settimana" do
    d = @scuola.disponibilita.new(tipo: "orario", account: @scuola.account)
    assert_not d.valid?
    assert_includes d.errors[:giorno_settimana], "non può essere lasciato in bianco"
  end

  test "chiusura requires data" do
    d = @scuola.disponibilita.new(tipo: "chiusura", account: @scuola.account)
    assert_not d.valid?
    assert_includes d.errors[:data], "non può essere lasciato in bianco"
  end

  test "patrono sets ricorrente automatically" do
    d = @scuola.disponibilita.create!(
      tipo: "patrono", data: "2026-12-07",
      titolo: "S. Ambrogio", account: @scuola.account
    )
    assert d.ricorrente?
  end

  test "chiusa_il? detects closure" do
    @scuola.disponibilita.create!(
      tipo: "chiusura", data: Date.tomorrow,
      titolo: "Ponte", account: @scuola.account
    )
    assert @scuola.chiusa_il?(Date.tomorrow)
    assert_not @scuola.chiusa_il?(Date.today)
  end

  test "chiusa_il? detects recurring patrono" do
    @scuola.disponibilita.create!(
      tipo: "patrono", data: "2025-12-07",
      titolo: "S. Ambrogio", account: @scuola.account
    )
    assert @scuola.chiusa_il?(Date.new(2026, 12, 7))
  end

  test "sede_seggio?" do
    assert_not @scuola.sede_seggio?
    @scuola.disponibilita.create!(tipo: "seggio", account: @scuola.account)
    assert @scuola.sede_seggio?
  end
end
