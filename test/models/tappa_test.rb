# == Schema Information
#
# Table name: tappe
#
#  id            :uuid             not null, primary key
#  data_tappa    :date
#  descrizione   :string
#  entro_il      :datetime
#  position      :integer          not null
#  tappable_type :string           not null
#  titolo        :string
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  account_id    :uuid             not null
#  giro_id       :bigint
#  tappable_id   :uuid
#  user_id       :bigint
#
# Indexes
#
#  index_tappe_on_account_id                           (account_id)
#  index_tappe_on_giro_id                              (giro_id)
#  index_tappe_on_tappable                             (tappable_type,tappable_id)
#  index_tappe_on_user_id                              (user_id)
#  index_tappe_on_user_id_and_data_tappa_and_position  (user_id,data_tappa,position) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (giro_id => giri.id)
#  fk_rails_...  (user_id => users.id)
#
require "test_helper"

class TappaTest < ActiveSupport::TestCase
  fixtures :accounts, :users, :memberships, :scuole

  setup do
    @fizzy = accounts(:fizzy)
    @user  = users(:one)
    @scuola = scuole(:scuola_fizzy)
    Current.account = @fizzy
    Current.user = @user

    @giro = Giro.create!(user: @user, titolo: "Giro Test")
    @altro_giro = Giro.create!(user: @user, titolo: "Altro Giro")
  end

  teardown do
    Current.reset
  end

  # Task 1 — Tappa.schedule_in_giro!

  test "schedule_in_giro! creates a new tappa with tappa_giro when none exists" do
    assert_difference -> { Tappa.count } => 1,
                      -> { TappaGiro.count } => 1 do
      @tappa = Tappa.schedule_in_giro!(
        user: @user,
        tappable: @scuola,
        giro: @giro,
        data_tappa: Date.tomorrow,
        titolo: "Visita"
      )
    end

    assert_equal @scuola, @tappa.tappable
    assert_equal Date.tomorrow, @tappa.data_tappa
    assert_equal "Visita", @tappa.titolo
    assert_equal @user, @tappa.user
    assert_includes @tappa.giri, @giro
  end

  test "schedule_in_giro! updates existing tappa with data_tappa nil in same giro" do
    existing = @user.tappe.create!(tappable: @scuola, data_tappa: nil, titolo: "Da programmare")
    existing.tappa_giri.create!(giro: @giro)

    assert_no_difference -> { Tappa.count } do
      result = Tappa.schedule_in_giro!(
        user: @user,
        tappable: @scuola,
        giro: @giro,
        data_tappa: Date.tomorrow,
        titolo: "Nuovo titolo"
      )
      assert_equal existing.id, result.id
    end

    existing.reload
    assert_equal Date.tomorrow, existing.data_tappa
    assert_equal "Nuovo titolo", existing.titolo
  end

  test "schedule_in_giro! creates new tappa when unscheduled exists only in another giro" do
    other = @user.tappe.create!(tappable: @scuola, data_tappa: nil, titolo: "Altra")
    other.tappa_giri.create!(giro: @altro_giro)

    assert_difference -> { Tappa.count } => 1 do
      @tappa = Tappa.schedule_in_giro!(
        user: @user,
        tappable: @scuola,
        giro: @giro,
        data_tappa: Date.tomorrow
      )
    end

    other.reload
    assert_nil other.data_tappa
    assert_not_equal other.id, @tappa.id
    assert_includes @tappa.giri, @giro
  end

  test "schedule_in_giro! creates new tappa and does not touch a future tappa in same giro" do
    future_date = Date.tomorrow + 5
    future = @user.tappe.create!(tappable: @scuola, data_tappa: future_date, titolo: "Futura")
    future.tappa_giri.create!(giro: @giro)

    assert_difference -> { Tappa.count } => 1 do
      @tappa = Tappa.schedule_in_giro!(
        user: @user,
        tappable: @scuola,
        giro: @giro,
        data_tappa: Date.tomorrow
      )
    end

    future.reload
    assert_equal future_date, future.data_tappa
    assert_equal "Futura", future.titolo
    assert_not_equal future.id, @tappa.id
  end

  test "schedule_in_giro! preserves existing titolo when titolo arg is nil" do
    existing = @user.tappe.create!(tappable: @scuola, data_tappa: nil, titolo: "Titolo originale")
    existing.tappa_giri.create!(giro: @giro)

    result = Tappa.schedule_in_giro!(
      user: @user,
      tappable: @scuola,
      giro: @giro,
      data_tappa: Date.tomorrow,
      titolo: nil
    )

    existing.reload
    assert_equal existing.id, result.id
    assert_equal "Titolo originale", existing.titolo
    assert_equal Date.tomorrow, existing.data_tappa
  end
end
