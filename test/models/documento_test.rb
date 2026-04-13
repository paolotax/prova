require "test_helper"

class DocumentoTest < ActiveSupport::TestCase
  fixtures :accounts, :users, :memberships, :documenti, :clienti, :causali

  setup do
    @fizzy = accounts(:fizzy)
    @user = users(:one)
    Current.account = @fizzy
    Current.user = @user
  end

  teardown do
    Current.reset
  end

  test "tappa_target is clientable when real" do
    documento = documenti(:documento_fizzy)
    assert_equal documento.clientable, documento.tappa_target
  end

  test "tappa_target is nil for NessunCliente" do
    documento = documenti(:documento_fizzy)
    documento.clientable = nil
    assert_instance_of Domain::NessunCliente, documento.clientable
    assert_nil documento.tappa_target
  end
end
