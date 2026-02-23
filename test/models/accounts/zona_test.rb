# == Schema Information
#
# Table name: account_zone
#
#  id              :uuid             not null, primary key
#  anno_scolastico :string
#  grado           :string           not null
#  provincia       :string           not null
#  regione         :string
#  scuole_count    :integer          default(0)
#  stato           :string           default("attiva")
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  account_id      :uuid             not null
#
# Indexes
#
#  idx_account_zone_unique           (account_id,provincia,grado,anno_scolastico) UNIQUE
#  index_account_zone_on_account_id  (account_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#
require "test_helper"

class Accounts::ZonaTest < ActiveSupport::TestCase
  fixtures :accounts, :users, :memberships, :account_zone

  setup do
    @fizzy = accounts(:fizzy)
    @acme = accounts(:acme)
    Current.account = @fizzy
  end

  teardown do
    Current.account = nil
  end

  test "validates provincia presence" do
    zona = Accounts::Zona.new(account: @fizzy, grado: "E", anno_scolastico: "2025/2026")
    assert_not zona.valid?
    assert zona.errors[:provincia].any?
  end

  test "validates grado presence" do
    zona = Accounts::Zona.new(account: @fizzy, provincia: "TO", anno_scolastico: "2025/2026")
    assert_not zona.valid?
    assert zona.errors[:grado].any?
  end

  test "validates uniqueness of provincia+grado+anno per account" do
    existing = account_zone(:fizzy_mi_primaria)
    zona = Accounts::Zona.new(
      account: @fizzy,
      provincia: existing.provincia,
      grado: existing.grado,
      anno_scolastico: existing.anno_scolastico
    )
    assert_not zona.valid?
    assert zona.errors[:provincia].any?
  end

  test "allows same provincia+grado for different accounts" do
    zona = Accounts::Zona.new(
      account: @acme,
      provincia: "MI",
      grado: "E",
      anno_scolastico: "2025/2026",
      regione: "Lombardia"
    )
    assert zona.valid?
  end

  test "grado_label returns human readable label" do
    zona_e = account_zone(:fizzy_mi_primaria)
    assert_equal "primaria", zona_e.grado_label

    zona_m = account_zone(:fizzy_mi_media)
    assert_equal "secondaria I grado", zona_m.grado_label

    zona_n = account_zone(:acme_rm_superiore)
    assert_equal "secondaria II grado", zona_n.grado_label
  end

  test "account association" do
    zona = account_zone(:fizzy_mi_primaria)
    assert_equal @fizzy, zona.account
  end

  test "scopes to current account" do
    fizzy_zone = Accounts::Zona.for_account(@fizzy)
    acme_zone = Accounts::Zona.for_account(@acme)

    assert fizzy_zone.include?(account_zone(:fizzy_mi_primaria))
    assert_not fizzy_zone.include?(account_zone(:acme_rm_superiore))
    assert acme_zone.include?(account_zone(:acme_rm_superiore))
  end
end
