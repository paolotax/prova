require "test_helper"

class LibriControllerTest < ActionDispatch::IntegrationTest
  setup do
    @libro = libri(:one)
  end

  test "should get index" do
    get libri_url
    assert_response :success
  end

  test "should get new" do
    get new_libro_url
    assert_response :success
  end

  test "should create libro" do
    assert_difference("Libro.count") do
      post libri_url, params: { libro: { categoria: @libro.categoria, classe: @libro.classe, codice_isbn: @libro.codice_isbn, disciplina: @libro.disciplina, editore_id: @libro.editore_id, note: @libro.note, prezzo_in_cents: @libro.prezzo_in_cents, titolo: @libro.titolo, user_id: @libro.user_id } }
    end

    assert_redirected_to libro_url(Libro.last)
  end

  test "should show libro" do
    get libro_url(@libro)
    assert_response :success
  end

  test "should get edit" do
    get edit_libro_url(@libro)
    assert_response :success
  end

  test "should update libro" do
    patch libro_url(@libro), params: { libro: { categoria: @libro.categoria, classe: @libro.classe, codice_isbn: @libro.codice_isbn, disciplina: @libro.disciplina, editore_id: @libro.editore_id, note: @libro.note, prezzo_in_cents: @libro.prezzo_in_cents, titolo: @libro.titolo, user_id: @libro.user_id } }
    assert_redirected_to libro_url(@libro)
  end

  test "should destroy libro" do
    assert_difference("Libro.count", -1) do
      delete libro_url(@libro)
    end

    assert_redirected_to libri_url
  end
end
