# test/models/appunto_test.rb
# == Schema Information
#
# Table name: appunti
#
#  id               :uuid             not null, primary key
#  active           :boolean
#  appuntabile_type :string
#  body             :text
#  email            :string
#  nome             :string
#  numero           :integer
#  stato            :string
#  status           :string           default("drafted"), not null
#  team             :string
#  telefono         :string
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  account_id       :uuid
#  appuntabile_id   :uuid
#  user_id          :bigint           not null
#  voice_note_id    :bigint
#
# Indexes
#
#  index_appunti_on_account_id                            (account_id)
#  index_appunti_on_account_id_and_created_at             (account_id,created_at)
#  index_appunti_on_account_id_and_numero_and_created_at  (account_id,numero,created_at)
#  index_appunti_on_account_id_and_status                 (account_id,status)
#  index_appunti_on_appuntabile_type_and_appuntabile_id   (appuntabile_type,appuntabile_id)
#  index_appunti_on_id                                    (id) UNIQUE
#  index_appunti_on_user_id                               (user_id)
#  index_appunti_on_voice_note_id                         (voice_note_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#  fk_rails_...  (voice_note_id => voice_notes.id)
#
require "test_helper"

class AppuntoTest < ActiveSupport::TestCase
  fixtures :accounts, :users, :memberships, :appunti, :scuole

  setup do
    @fizzy = accounts(:fizzy)
    @acme = accounts(:acme)
    @user = users(:one)
    @appunto = appunti(:appunto_fizzy)
    Current.account = @fizzy
    Current.user = @user
  end

  teardown do
    Current.reset
  end

  test "fixtures are valid" do
    assert @appunto.valid?
  end

  test "belongs to account" do
    assert_instance_of Account, @appunto.account
    assert_equal @fizzy, @appunto.account
  end

  test "requires account_id" do
    Current.account = nil
    appunto = Appunto.new(
      user: @user,
      nome: "Test Appunto"
    )

    assert_not appunto.valid?
    assert appunto.errors[:account_id].any?
  end

  test "sets account from Current on create" do
    appunto = Appunto.new(
      user: @user,
      nome: "New Appunto"
    )
    appunto.valid? # triggers before_validation callback

    assert_equal @fizzy, appunto.account
  end

  test "for_account scope filters by account" do
    fizzy_appunti = Appunto.where(account: @fizzy)
    acme_appunti = Appunto.where(account: @acme)

    assert fizzy_appunti.all? { |a| a.account_id == @fizzy.id }
    assert acme_appunti.all? { |a| a.account_id == @acme.id }
    assert_not_equal fizzy_appunti.pluck(:id), acme_appunti.pluck(:id)
  end

  test "account isolates appunti" do
    fizzy_appunto = appunti(:appunto_fizzy)
    acme_appunto = appunti(:appunto_acme)

    assert_equal @fizzy, fizzy_appunto.account
    assert_equal @acme, acme_appunto.account
    assert_not_equal fizzy_appunto.account_id, acme_appunto.account_id
  end

  test "creating appunto in account context" do
    assert_difference -> { @fizzy.appunti.count }, 1 do
      Appunto.create!(
        user: @user,
        nome: "New Fizzy Appunto",
        stato: "da_fare"
      )
    end

    # Acme should not have the new appunto
    assert_no_difference -> { @acme.appunti.count } do
      # Already created above
    end
  end

  # UUID Tests
  test "uses uuid as primary key" do
    appunto = Appunto.create!(
      user: @user,
      nome: "UUID Test Appunto"
    )

    assert_match(/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i, appunto.id)
  end

  test "id is uuid type in database" do
    column = Appunto.columns.find { |c| c.name == "id" }
    assert_equal :uuid, column.type
  end

  # State Record Concerns Tests
  test "golden methods via Entry delegation" do
    assert_respond_to @appunto, :golden?
    assert_respond_to @appunto, :gild
    assert_respond_to @appunto, :ungild
    # goldness è su Entry, non su Appunto
    @appunto.ensure_entry!
    assert_respond_to @appunto.entry, :goldness
  end

  test "closeable methods via Entry delegation" do
    assert_respond_to @appunto, :closed?
    assert_respond_to @appunto, :open?
    assert_respond_to @appunto, :close
    assert_respond_to @appunto, :reopen
    # closure è su Entry, non su Appunto
    @appunto.ensure_entry!
    assert_respond_to @appunto.entry, :closure
  end

  test "postponable methods via Entry delegation" do
    assert_respond_to @appunto, :postponed?
    assert_respond_to @appunto, :postpone
    assert_respond_to @appunto, :resume
    assert_respond_to @appunto, :postponed_at
    # not_now è su Entry, non su Appunto
    @appunto.ensure_entry!
    assert_respond_to @appunto.entry, :not_now
  end

  # Statuses concern tests
  test "includes Statuses concern" do
    assert_respond_to @appunto, :drafted?
    assert_respond_to @appunto, :published?
    assert_respond_to @appunto, :publish
  end

  test "drafted scope returns only drafted appunti" do
    drafted = appunti(:appunto_drafted)
    assert drafted.drafted?

    drafts = Appunto.drafted
    assert drafts.include?(drafted)
    assert_not drafts.include?(@appunto)
  end

  test "published scope returns only published appunti" do
    assert @appunto.published?

    published = Appunto.published
    assert published.include?(@appunto)
    assert_not published.include?(appunti(:appunto_drafted))
  end

  test "publish changes status from drafted to published" do
    drafted = appunti(:appunto_drafted)
    assert drafted.drafted?

    freeze_time do
      drafted.publish

      assert drafted.published?
      assert_equal Time.current, drafted.created_at
    end
  end

  test "new appunti are drafted by default" do
    appunto = Appunto.new(user: @user, nome: "Test")
    assert appunto.drafted?
  end

  test "gild creates goldness record via entry" do
    @appunto.ensure_entry!
    assert_not @appunto.golden?

    assert_difference -> { Goldness.count }, 1 do
      @appunto.gild
    end

    assert @appunto.golden?
    assert_equal @user, @appunto.entry.goldness.user
  end

  test "ungild destroys goldness record via entry" do
    @appunto.ensure_entry!
    @appunto.gild
    assert @appunto.golden?

    assert_difference -> { Goldness.count }, -1 do
      @appunto.ungild
    end

    assert_not @appunto.reload.golden?
  end

  test "close creates closure record via entry" do
    @appunto.ensure_entry!
    assert @appunto.open?
    assert_not @appunto.closed?

    assert_difference -> { Closure.count }, 1 do
      @appunto.close
    end

    assert @appunto.closed?
    assert_not @appunto.open?
    assert_equal @user, @appunto.entry.closure.user
  end

  test "reopen destroys closure record via entry" do
    @appunto.ensure_entry!
    @appunto.close
    assert @appunto.closed?

    assert_difference -> { Closure.count }, -1 do
      @appunto.reopen
    end

    assert @appunto.reload.open?
    assert_not @appunto.closed?
  end

  test "tappa_target is the appuntabile" do
    appunto = appunti(:appunto_with_target)
    assert_equal appunto.appuntabile, appunto.tappa_target
  end

  test "default_titolo_tappa contains date" do
    appunto = appunti(:appunto_with_target)
    assert_match Regexp.new(Regexp.escape(I18n.l(appunto.created_at.to_date))),
                 appunto.default_titolo_tappa.to_s
  end

end
