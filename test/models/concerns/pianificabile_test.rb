require "test_helper"

class PianificabileTest < ActiveSupport::TestCase
  class DummyTarget
    include Pianificabile
  end

  test "tappa_target returns self by default" do
    dummy = DummyTarget.new
    assert_equal dummy, dummy.tappa_target
  end

  test "default_titolo_tappa returns nil by default" do
    assert_nil DummyTarget.new.default_titolo_tappa
  end
end
