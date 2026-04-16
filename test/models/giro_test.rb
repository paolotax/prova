require "test_helper"

class GiroTest < ActiveSupport::TestCase
  fixtures :accounts, :users, :memberships

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
end
