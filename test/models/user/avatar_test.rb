require "test_helper"

class User::AvatarTest < ActiveSupport::TestCase
  fixtures :users

  setup do
    @user = users(:one)
  end

  test "avatar_thumbnail returns variant for variable images" do
    @user.avatar.attach(io: File.open(file_fixture("avatar.png")), filename: "avatar.png", content_type: "image/png")

    assert @user.avatar.variable?
    assert_equal @user.avatar.variant(:thumb).blob, @user.avatar_thumbnail.blob
  end

  test "allows valid image content types" do
    @user.avatar.attach(io: File.open(file_fixture("avatar.png")), filename: "test.png", content_type: "image/png")

    assert @user.valid?
  end

  # NOTE: process: :immediately richiede Rails 8.2+
  # In Rails 8.0.3 i variant vengono processati al primo accesso

  test "rejects images that are too wide" do
    @user.avatar.attach(io: File.open(file_fixture("avatar.png")), filename: "avatar.png", content_type: "image/png")
    @user.avatar.blob.update!(metadata: { analyzed: true, width: 5000, height: 100 })

    assert_not @user.valid?
    assert_includes @user.errors[:avatar], "width must be less than #{User::Avatar::MAX_AVATAR_DIMENSIONS[:width]}px"
  end

  test "rejects images that are too tall" do
    @user.avatar.attach(io: File.open(file_fixture("avatar.png")), filename: "avatar.png", content_type: "image/png")
    @user.avatar.blob.update!(metadata: { analyzed: true, width: 100, height: 5000 })

    assert_not @user.valid?
    assert_includes @user.errors[:avatar], "height must be less than #{User::Avatar::MAX_AVATAR_DIMENSIONS[:height]}px"
  end

  test "accepts images within dimension limits" do
    @user.avatar.attach(io: File.open(file_fixture("avatar.png")), filename: "avatar.png", content_type: "image/png")
    @user.avatar.blob.update!(metadata: { analyzed: true, width: 4096, height: 4096 })

    assert @user.valid?
  end
end
