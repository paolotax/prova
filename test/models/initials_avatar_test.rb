require "test_helper"

class InitialsAvatarTest < ActiveSupport::TestCase
  test "returns an embedded SVG without external requests" do
    uri = InitialsAvatar.data_uri("FL", color: "FFFFFF", background: "6B7280")
    svg = Base64.decode64(uri.delete_prefix("data:image/svg+xml;base64,"))

    assert uri.start_with?("data:image/svg+xml;base64,")
    assert_includes svg, ">FL</text>"
    assert_includes svg, "#FFFFFF"
    assert_includes svg, "#6B7280"
  end

  test "escapes initials and rejects invalid colors" do
    uri = InitialsAvatar.data_uri("<&", color: "red", background: "javascript:alert(1)")
    svg = Base64.decode64(uri.delete_prefix("data:image/svg+xml;base64,"))

    assert_includes svg, "&lt;&amp;"
    assert_includes svg, "#FFFFFF"
    assert_includes svg, "#6B7280"
  end
end
