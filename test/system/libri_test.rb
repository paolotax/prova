require "application_system_test_case"

class LibriTest < ApplicationSystemTestCase
  setup do
    @libro = libri(:one)
  end

  test "visiting the index" do
    visit libri_url
    assert_selector "h1", text: "Libri"
  end

  test "should create libro" do
    visit libri_url
    click_on "New libro"

    fill_in "Categoria", with: @libro.categoria
    fill_in "Classe", with: @libro.classe
    fill_in "Codice isbn", with: @libro.codice_isbn
    fill_in "Disciplina", with: @libro.disciplina
    fill_in "Editore", with: @libro.editore_id
    fill_in "Note", with: @libro.note
    fill_in "Prezzo in cents", with: @libro.prezzo_in_cents
    fill_in "Titolo", with: @libro.titolo
    fill_in "User", with: @libro.user_id
    click_on "Create Libro"

    assert_text "Libro was successfully created"
    click_on "Back"
  end

  test "should update Libro" do
    visit libro_url(@libro)
    click_on "Edit this libro", match: :first

    fill_in "Categoria", with: @libro.categoria
    fill_in "Classe", with: @libro.classe
    fill_in "Codice isbn", with: @libro.codice_isbn
    fill_in "Disciplina", with: @libro.disciplina
    fill_in "Editore", with: @libro.editore_id
    fill_in "Note", with: @libro.note
    fill_in "Prezzo in cents", with: @libro.prezzo_in_cents
    fill_in "Titolo", with: @libro.titolo
    fill_in "User", with: @libro.user_id
    click_on "Update Libro"

    assert_text "Libro was successfully updated"
    click_on "Back"
  end

  test "should destroy Libro" do
    visit libro_url(@libro)
    click_on "Destroy this libro", match: :first

    assert_text "Libro was successfully destroyed"
  end
end
