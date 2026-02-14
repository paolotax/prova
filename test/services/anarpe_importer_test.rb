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

  test "parse_classi_compact parses single class with multiple sezioni" do
    result = AnarpeImporter.parse_classi_compact("1BDE -")
    assert_equal [["1", "B"], ["1", "D"], ["1", "E"]], result
  end

  test "parse_classi_compact handles empty string" do
    assert_equal [], AnarpeImporter.parse_classi_compact("")
  end

  test "parse_classi_compact handles dash only" do
    assert_equal [], AnarpeImporter.parse_classi_compact("-")
  end

  # Separated digits and letters format
  test "parse_classi_compact parses separated digits and letters" do
    result = AnarpeImporter.parse_classi_compact(": 123 DEF -")
    assert_equal 9, result.size
    assert_includes result, ["1", "D"]
    assert_includes result, ["3", "F"]
  end

  test "parse_classi_compact parses all letters separated" do
    result = AnarpeImporter.parse_classi_compact(": 123 ABCDEF -")
    assert_equal 18, result.size
  end

  test "parse_classi_compact parses mixed tokens with noise prefix" do
    result = AnarpeImporter.parse_classi_compact("7 1AF 3B -")
    assert_includes result, ["1", "A"]
    assert_includes result, ["1", "F"]
    assert_includes result, ["3", "B"]
  end

  test "parse_classi_compact parses 12C 2F format" do
    result = AnarpeImporter.parse_classi_compact("- 12C 2F -")
    assert_includes result, ["1", "C"]
    assert_includes result, ["2", "C"]
    assert_includes result, ["2", "F"]
  end

  # Pure letters — OCR lost digits, default to years 1,2,3
  test "parse_classi_compact defaults to 123 for pure letters" do
    result = AnarpeImporter.parse_classi_compact("- AG-")
    assert_equal 6, result.size
    assert_includes result, ["1", "A"]
    assert_includes result, ["2", "A"]
    assert_includes result, ["3", "A"]
    assert_includes result, ["1", "G"]
    assert_includes result, ["2", "G"]
    assert_includes result, ["3", "G"]
  end

  test "parse_classi_compact defaults for pure letters with spaces" do
    result = AnarpeImporter.parse_classi_compact("- BCE -")
    assert_equal 9, result.size # 3 years x 3 letters
  end

  test "parse_classi_compact handles lowercase OCR noise" do
    # ": cD-" → uppercase → "CD" → defaults
    result = AnarpeImporter.parse_classi_compact(": cD-")
    assert_includes result, ["1", "C"]
    assert_includes result, ["1", "D"]
  end

  test "parse_classi_compact handles mixed with B1H format" do
    result = AnarpeImporter.parse_classi_compact("- B1H-")
    # B1H uppercase → "B1H" → mixed token: digits [1], letters [B,H] → 1B, 1H
    assert_includes result, ["1", "B"]
    assert_includes result, ["1", "H"]
  end

  # Sub-materia prefix stripping (high school format)
  test "parse_classi_compact strips dotted sub-materia prefix" do
    result = AnarpeImporter.parse_classi_compact("INF.5H -")
    assert_equal [["5", "H"]], result
  end

  test "parse_classi_compact strips dotted compound prefix" do
    result = AnarpeImporter.parse_classi_compact("TEC.MEC.3J 4N -")
    assert_includes result, ["3", "J"]
    assert_includes result, ["4", "N"]
  end

  test "parse_classi_compact strips short uppercase code prefix" do
    result = AnarpeImporter.parse_classi_compact("TPI 3G 4GH -")
    assert_includes result, ["3", "G"]
    assert_includes result, ["4", "G"]
    assert_includes result, ["4", "H"]
  end

  test "parse_classi_compact handles VARIE" do
    assert_equal [], AnarpeImporter.parse_classi_compact("- VARIE -")
    assert_equal [], AnarpeImporter.parse_classi_compact("VARIE -")
  end

  test "parse_classi_compact substitutes 0 for O" do
    result = AnarpeImporter.parse_classi_compact(": 40 5N -")
    assert_includes result, ["4", "O"]
    assert_includes result, ["5", "N"]
  end

  test "parse_classi_compact substitutes pipe for I" do
    result = AnarpeImporter.parse_classi_compact(": 2|J -")
    assert_includes result, ["2", "I"]
    assert_includes result, ["2", "J"]
  end
end
