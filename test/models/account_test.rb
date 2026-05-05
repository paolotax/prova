# test/models/account_test.rb
# == Schema Information
#
# Table name: accounts
#
#  id                                :uuid             not null, primary key
#  adozioni_aggiornamento_started_at :datetime
#  adozioni_aggiornate_at            :datetime
#  name                              :string           not null
#  slug                              :string
#  created_at                        :datetime         not null
#  updated_at                        :datetime         not null
#
# Indexes
#
#  index_accounts_on_slug  (slug) UNIQUE
#
require "test_helper"

class AccountTest < ActiveSupport::TestCase
  fixtures :accounts, :users, :memberships, :documenti, :clienti, :libri, :appunti,
           :causali, :categorie, :editori, :account_zone, :mandati

  setup do
    @account = accounts(:fizzy)
    @user = users(:one)
  end

  test "fixtures are valid" do
    assert @account.valid?
  end

  test "requires name" do
    @account.name = nil

    assert_not @account.valid?
    assert @account.errors[:name].any?
  end

  test "has many memberships" do
    assert_respond_to @account, :memberships
    assert @account.memberships.count > 0
  end

  test "has many users through memberships" do
    assert_respond_to @account, :users
    assert_includes @account.users, @user
  end

  test "has many documenti" do
    assert_respond_to @account, :documenti
    assert_equal 5, @account.documenti.count
  end

  test "has many clienti" do
    assert_respond_to @account, :clienti
    assert_equal 1, @account.clienti.count
  end

  test "has many libri" do
    assert_respond_to @account, :libri
    assert_equal 1, @account.libri.count
  end

  test "member? returns true for account member" do
    assert @account.member?(@user)
  end

  test "member? returns false for non-member" do
    non_member = users(:no_account)
    assert_not @account.member?(non_member)
  end

  test "add_member creates membership" do
    new_user = users(:no_account)

    assert_difference -> { @account.memberships.count }, 1 do
      @account.add_member(new_user, role: :member)
    end

    assert @account.member?(new_user)
  end

  test "add_member does not duplicate membership" do
    assert_no_difference -> { @account.memberships.count } do
      @account.add_member(@user, role: :member)
    end
  end

  test "remove_member destroys membership" do
    assert_difference -> { @account.memberships.count }, -1 do
      @account.remove_member(@user)
    end

    assert_not @account.member?(@user)
  end

  # --- aggiornamento_adozioni_in_corso? -------------------------------------

  test "aggiornamento_adozioni_in_corso? false when never started" do
    @account.update_columns(
      adozioni_aggiornamento_started_at: nil,
      adozioni_aggiornate_at: nil
    )

    assert_not @account.aggiornamento_adozioni_in_corso?
  end

  test "aggiornamento_adozioni_in_corso? true when started_at > aggiornate_at" do
    @account.update_columns(
      adozioni_aggiornamento_started_at: 1.minute.ago,
      adozioni_aggiornate_at: 1.hour.ago
    )

    assert @account.aggiornamento_adozioni_in_corso?
  end

  test "aggiornamento_adozioni_in_corso? false when aggiornate_at > started_at" do
    @account.update_columns(
      adozioni_aggiornamento_started_at: 1.hour.ago,
      adozioni_aggiornate_at: 1.minute.ago
    )

    assert_not @account.aggiornamento_adozioni_in_corso?
  end

  test "aggiornamento_adozioni_in_corso? true when started_at set and aggiornate_at nil" do
    @account.update_columns(
      adozioni_aggiornamento_started_at: 1.minute.ago,
      adozioni_aggiornate_at: nil
    )

    assert @account.aggiornamento_adozioni_in_corso?
  end

  # --- adozioni_stale? ------------------------------------------------------

  test "adozioni_stale? true when adozioni_aggiornate_at is nil" do
    @account.update_columns(
      adozioni_aggiornamento_started_at: nil,
      adozioni_aggiornate_at: nil
    )

    assert @account.adozioni_stale?
  end

  test "adozioni_stale? false when currently in progress" do
    @account.update_columns(
      adozioni_aggiornamento_started_at: 1.minute.ago,
      adozioni_aggiornate_at: 1.hour.ago
    )

    assert_not @account.adozioni_stale?
  end

  test "adozioni_stale? true when a zona was modified after last update" do
    @account.update_columns(
      adozioni_aggiornamento_started_at: 2.hours.ago,
      adozioni_aggiornate_at: 1.hour.ago
    )
    zona = @account.zone.first
    zona.update_columns(updated_at: 1.minute.ago)

    assert @account.adozioni_stale?
  end

  test "adozioni_stale? false when zone and mandati untouched since last update" do
    @account.zone.update_all(updated_at: 1.hour.ago)
    @account.mandati.update_all(updated_at: 1.hour.ago)
    @account.update_columns(
      adozioni_aggiornamento_started_at: 30.minutes.ago,
      adozioni_aggiornate_at: 5.minutes.ago
    )

    assert_not @account.adozioni_stale?
  end

  # --- zone_tutte_attive? ---------------------------------------------------

  test "zone_tutte_attive? true when all zones in state attiva" do
    @account.zone.update_all(stato: "attiva")

    assert @account.zone_tutte_attive?
  end

  test "zone_tutte_attive? false when at least one zone in state importazione" do
    @account.zone.update_all(stato: "attiva")
    @account.zone.first.update_columns(stato: "importazione")

    assert_not @account.zone_tutte_attive?
  end

  # --- estendi_mandati_a_zona! ----------------------------------------------

  test "estendi_mandati_a_zona! creates a mandato per editore attivo" do
    editori_attivi = @account.mandati.attivi.select(:editore_id).distinct.pluck(:editore_id)
    assert editori_attivi.any?, "fixture deve avere almeno un mandato attivo"

    assert_difference -> { @account.mandati.where(provincia: "BO", grado: "E").count },
                      editori_attivi.size do
      @account.estendi_mandati_a_zona!(provincia: "BO", grado: "E")
    end
  end

  test "estendi_mandati_a_zona! is idempotent on second call" do
    @account.estendi_mandati_a_zona!(provincia: "BO", grado: "E")
    count_after_first = @account.mandati.where(provincia: "BO", grado: "E").count

    assert_no_difference -> { @account.mandati.where(provincia: "BO", grado: "E").count } do
      @account.estendi_mandati_a_zona!(provincia: "BO", grado: "E")
    end

    assert count_after_first > 0
  end

  test "estendi_mandati_a_zona! is a noop when no mandati attivi" do
    @account.mandati.update_all(disdetta: true)

    assert_no_difference -> { @account.mandati.count } do
      @account.estendi_mandati_a_zona!(provincia: "BO", grado: "E")
    end
  end
end
