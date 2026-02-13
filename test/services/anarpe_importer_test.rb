require "test_helper"

class AnarpeImporterTest < ActiveSupport::TestCase
  test "parse_classi_compact parses simple pair" do
    result = AnarpeImporter.parse_classi_compact("3C 2F -")
    assert_equal [["3", "C"], ["2", "F"]], result
  end

  test "parse_classi_compact parses multi-sezione same anno" do
    result = AnarpeImporter.parse_classi_compact("1AF 3B -")
    assert_equal [["1", "A"], ["1", "F"], ["3", "B"]], result
  end

  test "parse_classi_compact parses multi-anno multi-sezione" do
    result = AnarpeImporter.parse_classi_compact("12AG 1EH -")
    expected = [["1", "A"], ["2", "A"], ["1", "G"], ["2", "G"], ["1", "E"], ["1", "H"]]
    assert_equal expected, result
  end

  test "parse_classi_compact parses single sezione without anno" do
    result = AnarpeImporter.parse_classi_compact("E -")
    assert_equal [["E"]], result
  end

  test "parse_classi_compact parses single class with multiple sezioni" do
    result = AnarpeImporter.parse_classi_compact("1BDE -")
    assert_equal [["1", "B"], ["1", "D"], ["1", "E"]], result
  end

  test "parse_classi_compact handles empty string" do
    result = AnarpeImporter.parse_classi_compact("")
    assert_equal [], result
  end

  test "parse_classi_compact handles dash only" do
    result = AnarpeImporter.parse_classi_compact("-")
    assert_equal [], result
  end
end
