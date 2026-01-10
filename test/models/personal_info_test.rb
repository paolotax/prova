# == Schema Information
#
# Table name: personal_infos
#
#  id              :uuid             not null, primary key
#  cellulare       :string
#  cognome         :string
#  email_personale :string
#  navigator       :string
#  nome            :string
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  user_id         :bigint           not null
#
# Indexes
#
#  index_personal_infos_on_user_id  (user_id) UNIQUE
#
require "test_helper"

class PersonalInfoTest < ActiveSupport::TestCase
  fixtures :users, :personal_infos

  setup do
    @personal_info = personal_infos(:alice_info)
    @user = users(:one)
  end

  # Validations
  test "valid personal_info" do
    assert @personal_info.valid?
  end

  test "requires nome" do
    @personal_info.nome = nil
    assert_not @personal_info.valid?
    assert @personal_info.errors[:nome].any?
  end

  test "requires cognome" do
    @personal_info.cognome = nil
    assert_not @personal_info.valid?
    assert @personal_info.errors[:cognome].any?
  end

  test "user_id must be unique" do
    duplicate = PersonalInfo.new(
      user: @user,
      nome: "Test",
      cognome: "User"
    )
    assert_not duplicate.valid?
    assert @personal_info.errors[:user_id].any? || duplicate.errors[:user_id].any?
  end

  # Computed attributes
  test "nome_completo returns full name" do
    assert_equal "Alice Rossi", @personal_info.nome_completo
  end

  test "nome_completo handles blank values" do
    @personal_info.cognome = ""
    assert_equal "Alice", @personal_info.nome_completo
  end

  test "iniziali returns initials from nome and cognome" do
    assert_equal "AR", @personal_info.iniziali
  end

  test "iniziali falls back to user name when nome/cognome blank" do
    info = PersonalInfo.new(user: users(:no_account), nome: "", cognome: "")
    # user name is "dana", so should get "DA"
    assert_equal "DA", info.iniziali
  end

  # Avatar color
  test "avatar_color returns a valid tailwind color class" do
    color = @personal_info.avatar_color
    assert color.start_with?("bg-")
    assert color.end_with?("-500")
  end

  test "avatar_color is deterministic for same name" do
    color1 = @personal_info.avatar_color
    color2 = @personal_info.avatar_color
    assert_equal color1, color2
  end

  test "different names produce different colors" do
    alice_color = personal_infos(:alice_info).avatar_color
    bob_color = personal_infos(:bob_info).avatar_color
    # Different names should (usually) produce different colors
    # This could occasionally fail if two names happen to hash to same color
    # but with our test data it should be different
    assert_not_equal alice_color, bob_color
  end

  # Avatar helpers
  test "has_avatar? returns false when no avatar attached" do
    assert_not @personal_info.has_avatar?
  end

  test "avatar_url returns nil when no avatar attached" do
    assert_nil @personal_info.avatar_url
  end

  # Avatar data
  test "avatar_data returns hash with all required keys" do
    data = @personal_info.avatar_data

    assert_includes data.keys, :has_image
    assert_includes data.keys, :initials
    assert_includes data.keys, :color
    assert_includes data.keys, :name
  end

  test "avatar_data returns correct values" do
    data = @personal_info.avatar_data

    assert_equal false, data[:has_image]
    assert_equal "AR", data[:initials]
    assert_equal "Alice Rossi", data[:name]
    assert data[:color].start_with?("bg-")
  end

  # Association
  test "belongs to user" do
    assert_equal @user, @personal_info.user
  end
end
