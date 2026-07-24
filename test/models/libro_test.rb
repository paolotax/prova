# frozen_string_literal: true

# == Schema Information
#
# Table name: libri
#
#  id                     :bigint           not null, primary key
#  adozioni_count         :integer          default(0), not null
#  classe                 :integer
#  cm                     :string
#  codice_isbn            :string
#  collana                :string
#  confezioni_count       :integer          default(0), not null
#  disciplina             :string
#  fascicoli_count        :integer          default(0), not null
#  note                   :text
#  numero_fascicoli       :integer
#  prezzo_in_cents        :integer
#  prezzo_suggerito_cents :integer          default(0)
#  slug                   :string
#  titolo                 :string
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  account_id             :uuid             not null
#  categoria_id           :bigint           not null
#  editore_id             :bigint
#  prosegue_in_id         :bigint
#  user_id                :bigint           not null
#
# Indexes
#
#  index_libri_on_account_id                 (account_id)
#  index_libri_on_account_id_and_created_at  (account_id,created_at)
#  index_libri_on_categoria_id               (categoria_id)
#  index_libri_on_classe_and_disciplina      (classe,disciplina)
#  index_libri_on_cm                         (cm)
#  index_libri_on_editore_id                 (editore_id)
#  index_libri_on_prosegue_in_id             (prosegue_in_id)
#  index_libri_on_slug                       (slug) UNIQUE
#  index_libri_on_user_id                    (user_id)
#  index_libri_on_user_id_and_codice_isbn    (user_id,codice_isbn)
#  index_libri_on_user_id_and_collana        (user_id,collana)
#  index_libri_on_user_id_and_editore_id     (user_id,editore_id)
#  index_libri_on_user_id_and_titolo         (user_id,titolo)
#
# Foreign Keys
#
#  fk_rails_...  (categoria_id => categorie.id)
#  fk_rails_...  (editore_id => editori.id)
#  fk_rails_...  (user_id => users.id)
#
require "test_helper"

class LibroTest < ActiveSupport::TestCase
  fixtures :accounts, :users, :memberships, :categorie

  setup do
    @account = accounts(:fizzy)
    @user = users(:one)
    Current.account = @account
    Current.user = @user
  end

  teardown do
    Current.reset
  end

  test "candidati_prosegui infersce il volume successivo per titolo-base e categoria, con eccezione LIBRO DELLA PRIMA -> SUSSIDIARIO" do
    l1 = crea_libro(titolo: "Banda Bus 1", classe: 1, disciplina: "IL LIBRO DELLA PRIMA CLASSE")
    l2 = crea_libro(titolo: "Banda Bus 2", classe: 2, disciplina: "SUSSIDIARIO (1° BIENNIO)")
    # stessa disciplina di destinazione ma titolo-base diverso: escluso
    crea_libro(titolo: "Altro Libro 2", classe: 2, disciplina: "SUSSIDIARIO (1° BIENNIO)")
    # stesso titolo-base ma categoria diversa: escluso
    crea_libro(titolo: "Banda Bus 2", classe: 2, disciplina: "SUSSIDIARIO (1° BIENNIO)",
               categoria: categorie(:parascolastico))

    assert_equal [l2], l1.candidati_prosegui

    l1.update!(prosegue_in: l2)
    assert_equal l2, l1.reload.prosegue_in
    assert_equal l1, l2.reload.precedente
  end

  test "candidati_prosegui segue la stessa disciplina quando non e' primo biennio" do
    fonte = crea_libro(titolo: "Sussidiario Blu 2", classe: 2, disciplina: "SUSSIDIARIO (1° BIENNIO)")
    match = crea_libro(titolo: "Sussidiario Blu 3", classe: 3, disciplina: "SUSSIDIARIO (1° BIENNIO)")

    assert_equal [match], fonte.candidati_prosegui
  end

  test "candidati_prosegui filtra per disciplina: stesso titolo-base ma disciplina diversa escluso" do
    fonte = crea_libro(titolo: "Sussidiario Blu 2", classe: 2, disciplina: "SUSSIDIARIO (1° BIENNIO)")
    crea_libro(titolo: "Sussidiario Blu 3", classe: 3, disciplina: "LINGUA INGLESE")

    assert_empty fonte.candidati_prosegui
  end

  test "candidati_prosegui senza disciplina sulla fonte matcha su categoria+classe+titolo-base" do
    fonte = crea_libro(titolo: "Geo Lab 2", classe: 2, disciplina: nil)
    match = crea_libro(titolo: "Geo Lab 3", classe: 3, disciplina: "LINGUA INGLESE")

    assert_equal [match], fonte.candidati_prosegui
  end

  test "titolo_base normalizza punteggiatura e rimuove i numeri di volume ovunque" do
    assert_equal "BANDA BUS",       crea_libro(titolo: "BANDA BUS 1", classe: 1).titolo_base
    assert_equal "SUSSIDIARIO VOL", crea_libro(titolo: "Sussidiario Vol. 2", classe: 2).titolo_base
    assert_equal "GEO LAB",         crea_libro(titolo: "GEO LAB", classe: 3).titolo_base
    # numero in mezzo al titolo (caso reale) e punteggiatura variabile
    assert_equal "BANDA DEL BUS MATEMATICA",
                 crea_libro(titolo: "BANDA DEL BUS 1 MATEMATICA", classe: 1).titolo_base
    assert_equal "BANDA DEL BUS CL CONF PROP",
                 crea_libro(titolo: "BANDA DEL BUS CL. 1  CONF. PROP.", classe: 1).titolo_base
    # i numeri lunghi (annate) non sono volumi: restano
    assert_equal "STORIA 2000", crea_libro(titolo: "STORIA 2000", classe: 3).titolo_base
  end

  test "candidati_prosegui sul salto biennio matcha per serie (qualificatori di metodo)" do
    # Il libro della prima ha il qualificatore (STAMPATO), il sussidiario no:
    # titolo-base diverso ma stessa serie → deve agganciare comunque.
    l1 = crea_libro(titolo: "BANDA DEL BUS CL. 1 STAMPATO", classe: 1,
                    disciplina: "IL LIBRO DELLA PRIMA CLASSE")
    l2 = crea_libro(titolo: "BANDA DEL BUS CL. 2 CONFEZIONE VENDITA", classe: 2,
                    disciplina: "SUSSIDIARIO (1° BIENNIO)")
    crea_libro(titolo: "BOSCO ALLEGRO CL. 2", classe: 2, disciplina: "SUSSIDIARIO (1° BIENNIO)")

    assert_equal [l2], l1.candidati_prosegui
  end

  test "candidati_prosegui aggancia anche col numero in mezzo al titolo" do
    fonte = crea_libro(titolo: "BANDA DEL BUS 1 MATEMATICA", classe: 1, disciplina: "MATEMATICA")
    match = crea_libro(titolo: "BANDA DEL BUS 2 MATEMATICA", classe: 2, disciplina: "MATEMATICA")

    assert_equal [match], fonte.candidati_prosegui
  end

  test "opzioni_prosegui propone categoria+classe successiva coi titoli simili in testa, senza filtri duri" do
    fonte   = crea_libro(titolo: "BANDA DEL BUS 1 LETTURE GRAMMATICA", classe: 1, disciplina: "LETTURE")
    simile  = crea_libro(titolo: "BANDA DEL BUS 2 LETTURE GRAMMATICA", classe: 2, disciplina: "ITALIANO")
    altro   = crea_libro(titolo: "ZAINETTO 2", classe: 2, disciplina: "ITALIANO")
    crea_libro(titolo: "FUORI CLASSE 3", classe: 3, disciplina: "ITALIANO")

    opzioni = fonte.opzioni_prosegui
    # disciplina derivata (LETTURE -> ITALIANO): il simile c'e' comunque, e per primo
    assert_equal simile, opzioni.first
    assert_includes opzioni, altro
    # solo classe+1, non tutto il catalogo
    assert opzioni.all? { |l| l.classe == 2 }
  end

  private

  def crea_libro(titolo:, classe: nil, disciplina: nil, categoria: nil)
    Libro.create!(
      account: @account,
      user: @user,
      categoria: categoria || categorie(:ministeriali),
      titolo: titolo,
      classe: classe,
      disciplina: disciplina,
      codice_isbn: SecureRandom.hex(6),
      prezzo_in_cents: 1000
    )
  end
end
