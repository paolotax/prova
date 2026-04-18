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

  # Task — genera_tappe_per con merge

  test "#genera_tappe_per mergia una tappa esistente invece di duplicare" do
    scuola = scuole(:scuola_fizzy)
    giro_a = @user.giri.create!(titolo: "Giro A")
    giro_b = @user.giri.create!(
      titolo: "Giro B",
      iniziato_il: Date.current - 1.week, finito_il: Date.current + 1.week
    )

    tappa_esistente = @user.tappe.create!(tappable: scuola, data_tappa: Date.current)
    tappa_esistente.tappa_giri.create!(giro: giro_a)

    assert_no_difference "Tappa.count" do
      giro_b.genera_tappe_per(school_ids: [scuola.id], user: @user)
    end

    tappa_esistente.reload
    assert_includes tappa_esistente.giri, giro_a
    assert_includes tappa_esistente.giri, giro_b
    assert_equal Date.current, tappa_esistente.data_tappa
  end

  test "#genera_tappe_per crea tappa nuova quando scuola non ha tappe" do
    scuola = scuole(:scuola_fizzy_nord)
    giro = @user.giri.create!(titolo: "Giro nuovo")

    assert_difference "Tappa.count", 1 do
      giro.genera_tappe_per(school_ids: [scuola.id], user: @user)
    end

    tappa = giro.tappe.last
    assert_equal scuola, tappa.tappable
    assert_nil tappa.data_tappa
  end

  test "#genera_tappe_per è idempotente: non duplica l'associazione" do
    scuola = scuole(:scuola_fizzy)
    giro = @user.giri.create!(titolo: "Giro")

    giro.genera_tappe_per(school_ids: [scuola.id], user: @user)
    assert_no_difference ["Tappa.count", "TappaGiro.count"] do
      giro.genera_tappe_per(school_ids: [scuola.id], user: @user)
    end
  end

  # svuota_tappe! — preserva tappe multi-giro

  test "#svuota_tappe! elimina le tappe appartenenti solo a questo giro" do
    scuola = scuole(:scuola_fizzy)
    giro = @user.giri.create!(titolo: "Solo")
    tappa = @user.tappe.create!(tappable: scuola, data_tappa: nil)
    tappa.tappa_giri.create!(giro: giro)

    assert_difference "Tappa.count", -1 do
      count = giro.svuota_tappe!
      assert_equal 1, count
    end
  end

  test "#svuota_tappe! mantiene le tappe condivise con altri giri" do
    scuola = scuole(:scuola_fizzy)
    giro_a = @user.giri.create!(titolo: "A")
    giro_b = @user.giri.create!(titolo: "B")
    tappa = @user.tappe.create!(tappable: scuola, data_tappa: nil)
    tappa.tappa_giri.create!(giro: giro_a)
    tappa.tappa_giri.create!(giro: giro_b)

    assert_no_difference "Tappa.count" do
      assert_difference "TappaGiro.count", -1 do
        count = giro_b.svuota_tappe!
        assert_equal 1, count
      end
    end

    tappa.reload
    assert_includes tappa.giri, giro_a
    refute_includes tappa.giri, giro_b
  end
end
