# test/models/account_test.rb
# == Schema Information
#
# Table name: accounts
#
#  id         :uuid             not null, primary key
#  name       :string           not null
#  slug       :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_accounts_on_slug  (slug) UNIQUE
#
require "test_helper"

class AccountTest < ActiveSupport::TestCase
  fixtures :accounts, :users, :memberships, :documenti, :clienti, :libri, :appunti,
           :causali, :categorie, :editori

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
    assert_equal 1, @account.documenti.count
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
end
