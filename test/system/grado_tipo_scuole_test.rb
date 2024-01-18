require "application_system_test_case"

class GradoTipoScuoleTest < ApplicationSystemTestCase
  setup do
    @grado_tipo_scuola = grado_tipo_scuole(:one)
  end

  test "visiting the index" do
    visit grado_tipo_scuole_url
    assert_selector "h1", text: "Grado tipo scuole"
  end

  test "should create grado tipo scuola" do
    visit grado_tipo_scuole_url
    click_on "New grado tipo scuola"

    fill_in "Grado", with: @grado_tipo_scuola.grado
    fill_in "Tipo", with: @grado_tipo_scuola.tipo
    click_on "Create Grado tipo scuola"

    assert_text "Grado tipo scuola was successfully created"
    click_on "Back"
  end

  test "should update Grado tipo scuola" do
    visit grado_tipo_scuola_url(@grado_tipo_scuola)
    click_on "Edit this grado tipo scuola", match: :first

    fill_in "Grado", with: @grado_tipo_scuola.grado
    fill_in "Tipo", with: @grado_tipo_scuola.tipo
    click_on "Update Grado tipo scuola"

    assert_text "Grado tipo scuola was successfully updated"
    click_on "Back"
  end

  test "should destroy Grado tipo scuola" do
    visit grado_tipo_scuola_url(@grado_tipo_scuola)
    click_on "Destroy this grado tipo scuola", match: :first

    assert_text "Grado tipo scuola was successfully destroyed"
  end
end
