require "test_helper"

class AnnoScolasticoTest < ActiveSupport::TestCase
  test "corrente delega a Miur.anno_corrente" do
    Miur.stubs(:anno_corrente).returns("202627")
    assert_equal "202627", AnnoScolastico.corrente.to_s
  end

  test "corrente e' nil quando Miur.anno_corrente e' nil" do
    Miur.stubs(:anno_corrente).returns(nil)
    assert_nil AnnoScolastico.corrente
  end

  test "successivo e precedente scorrono di un anno" do
    a = AnnoScolastico.new("202526")
    assert_equal "202627", a.successivo.to_s
    assert_equal "202425", a.precedente.to_s
  end

  test "label umana" do
    assert_equal "2025/26", AnnoScolastico.new("202526").label
  end

  test "comparabile e uguale per valore" do
    assert AnnoScolastico.new("202627") > AnnoScolastico.new("202526")
    assert_equal AnnoScolastico.new("202526"), AnnoScolastico.new("202526")
  end
end
