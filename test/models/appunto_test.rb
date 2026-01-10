# test/models/appunto_test.rb
# == Schema Information
#
# Table name: appunti
#
#  id                 :bigint           not null, primary key
#  active             :boolean
#  body               :text
#  completed_at       :datetime
#  email              :string
#  nome               :string
#  stato              :string
#  team               :string
#  telefono           :string
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  account_id         :uuid
#  classe_id          :bigint
#  import_adozione_id :bigint
#  import_scuola_id   :bigint
#  user_id            :bigint           not null
#  voice_note_id      :bigint
#
# Indexes
#
#  index_appunti_on_account_id                 (account_id)
#  index_appunti_on_account_id_and_created_at  (account_id,created_at)
#  index_appunti_on_classe_id                  (classe_id)
#  index_appunti_on_import_adozione_id         (import_adozione_id)
#  index_appunti_on_import_scuola_id           (import_scuola_id)
#  index_appunti_on_user_id                    (user_id)
#  index_appunti_on_voice_note_id              (voice_note_id)
#
# Foreign Keys
#
#  fk_rails_...  (import_adozione_id => import_adozioni.id)
#  fk_rails_...  (import_scuola_id => import_scuole.id)
#  fk_rails_...  (user_id => users.id)
#  fk_rails_...  (voice_note_id => voice_notes.id)
#
require "test_helper"

class AppuntoTest < ActiveSupport::TestCase
  fixtures :accounts, :users, :memberships, :appunti

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
end
