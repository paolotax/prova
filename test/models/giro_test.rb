# == Schema Information
#
# Table name: giri
#
#  id          :bigint           not null, primary key
#  color       :string           default("var(--color-card-default)")
#  conditions  :text
#  descrizione :string
#  finito_il   :datetime
#  iniziato_il :datetime
#  stato       :string
#  tipo_giro   :string
#  titolo      :string
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  account_id  :uuid             not null
#  collana_id  :uuid
#  user_id     :bigint           not null
#
# Indexes
#
#  index_giri_on_account_id  (account_id)
#  index_giri_on_collana_id  (collana_id)
#  index_giri_on_user_id     (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (user_id => users.id)
#
require "test_helper"

class GiroTest < ActiveSupport::TestCase
  fixtures :accounts, :users, :memberships, :scuole

  setup do
    @fizzy = accounts(:fizzy)
    @user  = users(:one)
    Current.account = @fizzy
    Current.user = @user
  end

  teardown { Current.reset }

  # Task 3 — set_default_finito_il

  test "sets finito_il to iniziato_il + 4 weeks when blank" do
    giro = @user.giri.new(titolo: "G1", iniziato_il: Date.current)
    giro.valid?
    assert_equal Date.current + 4.weeks, giro.finito_il.to_date
  end

  test "does not override finito_il when already set and >= iniziato_il" do
    iniziato = Date.current
    finito   = iniziato + 1.week
    giro = @user.giri.new(titolo: "G2", iniziato_il: iniziato, finito_il: finito)
    giro.valid?
    assert_equal finito, giro.finito_il.to_date
  end

  test "resets finito_il when before iniziato_il" do
    iniziato = Date.current
    giro = @user.giri.new(titolo: "G3", iniziato_il: iniziato, finito_il: iniziato - 1.day)
    giro.valid?
    assert_equal iniziato + 4.weeks, giro.finito_il.to_date
  end

  test "does nothing when iniziato_il is blank" do
    giro = @user.giri.new(titolo: "G4")
    giro.valid?
    assert_nil giro.finito_il
  end

  # Task 4 — presentation methods

  test "#settimane returns array of weeks covering iniziato_il to finito_il" do
    giro = @user.giri.create!(
      titolo: "G",
      iniziato_il: Date.new(2026, 1, 5),  # Monday
      finito_il:   Date.new(2026, 1, 18)  # Sunday (2 weeks later)
    )
    weeks = giro.settimane
    assert_equal 2, weeks.size
    assert_equal Date.new(2026, 1, 5), weeks.first.first
    assert_equal Date.new(2026, 1, 18), weeks.last.last
  end

  test "#settimane returns [] when dates blank" do
    giro = @user.giri.new(titolo: "G")
    assert_equal [], giro.settimane
  end

  test "#settimane returns [] when range > 365 days" do
    giro = @user.giri.new(
      titolo: "G",
      iniziato_il: Date.current,
      finito_il: Date.current + 400
    )
    assert_equal [], giro.settimane
  end

  test "#giorni_timeline marks today and past" do
    giro = @user.giri.new(titolo: "G")
    tappe_per_giorno = {
      Date.current - 1 => [1, 2],
      Date.current     => [3],
      Date.current + 1 => [4, 5, 6]
    }
    timeline = giro.giorni_timeline(tappe_per_giorno)
    assert_equal 3, timeline.size
    assert timeline[0][:past]
    assert timeline[1][:today]
    refute timeline[2][:past]
    refute timeline[2][:today]
    assert_equal 3, timeline[2][:count]
  end

  test "#tappe_per_giorno groups tappe by data_tappa" do
    giro = @user.giri.create!(titolo: "Gx")
    scuola = scuole(:scuola_fizzy)
    monday = Date.current.beginning_of_week
    t1 = @user.tappe.create!(tappable: scuola, data_tappa: monday)
    t2 = @user.tappe.create!(tappable: scuola, data_tappa: monday + 1)
    [t1, t2].each { |t| t.tappa_giri.create!(giro: giro) }

    result = giro.tappe_per_giorno
    assert_equal [t1], result[monday]
    assert_equal [t2], result[monday + 1]
  end

  test "#tappe_totali returns count of all tappe" do
    giro = @user.giri.create!(titolo: "Gtot")
    scuola = scuole(:scuola_fizzy)
    t = @user.tappe.create!(tappable: scuola, data_tappa: Date.current)
    t.tappa_giri.create!(giro: giro)
    assert_equal 1, giro.tappe_totali
  end

  test "#tappe_completate counts tappe with past data_tappa" do
    giro = @user.giri.create!(titolo: "Gcomp")
    scuola = scuole(:scuola_fizzy)
    t_past   = @user.tappe.create!(tappable: scuola, data_tappa: Date.current - 1)
    t_future = @user.tappe.create!(tappable: scuola, data_tappa: Date.current + 1)
    [t_past, t_future].each { |t| t.tappa_giri.create!(giro: giro) }
    assert_equal 1, giro.tappe_completate
  end
end
