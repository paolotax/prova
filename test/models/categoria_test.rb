# frozen_string_literal: true

require "test_helper"

class CategoriaTest < ActiveSupport::TestCase
  fixtures :accounts, :users, :memberships, :categorie

  setup do
    @user = users(:one)
    @account = accounts(:fizzy)
  end

  # --- Normalization ---

  test "normalizes nome_categoria to lowercase on save" do
    cat = Categoria.create!(nome_categoria: "VACANZE", user: @user, account_id: @account.id)
    assert_equal "vacanze", cat.nome_categoria
  end

  test "strips whitespace from nome_categoria on save" do
    cat = Categoria.create!(nome_categoria: "  guide  ", user: @user, account_id: @account.id)
    assert_equal "guide", cat.nome_categoria
  end

  # --- Uniqueness (case-insensitive) ---

  test "prevents duplicate category names case-insensitively" do
    Categoria.create!(nome_categoria: "vacanze", user: @user, account_id: @account.id)
    dup = Categoria.new(nome_categoria: "VACANZE", user: @user, account_id: @account.id)
    assert_not dup.valid?
    assert_includes dup.errors[:nome_categoria], "è già presente"
  end

  # --- Resolve ---

  test "resolve finds existing category case-insensitively" do
    existing = categorie(:ministeriali)
    found = Categoria.resolve("MINISTERIALI", user: @user, account: @account)
    assert_equal existing.id, found.id
  end

  test "resolve creates new category if not found" do
    assert_difference "Categoria.count", 1 do
      cat = Categoria.resolve("nuova categoria", user: @user, account: @account)
      assert_equal "nuova categoria", cat.nome_categoria
      assert_equal @user.id, cat.user_id
      assert_equal @account.id, cat.account_id
    end
  end

  test "resolve returns default category when nome is nil" do
    cat = Categoria.resolve(nil, user: @user, account: @account)
    assert_equal "non classificato", cat.nome_categoria
  end

  test "resolve returns default category when nome is blank" do
    cat = Categoria.resolve("", user: @user, account: @account)
    assert_equal "non classificato", cat.nome_categoria
  end

  test "resolve strips and downcases before matching" do
    existing = categorie(:parascolastico)
    found = Categoria.resolve("  PARASCOLASTICO  ", user: @user, account: @account)
    assert_equal existing.id, found.id
  end

  test "resolve is idempotent" do
    first = Categoria.resolve("test_idem", user: @user, account: @account)
    assert_no_difference "Categoria.count" do
      second = Categoria.resolve("TEST_IDEM", user: @user, account: @account)
      assert_equal first.id, second.id
    end
  end
end
