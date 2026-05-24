# == Schema Information
#
# Table name: confezione_righe
#
#  id            :bigint           not null, primary key
#  row_order     :integer
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  confezione_id :bigint
#  fascicolo_id  :bigint
#
require "test_helper"

class ConfezioneRigaTest < ActiveSupport::TestCase
  fixtures :accounts, :users, :editori, :categorie, :libri, :confezione_righe

  test "validazione no-self-reference: confezione e fascicolo non possono coincidere" do
    libro = libri(:libro_fizzy)
    pivot = ConfezioneRiga.new(confezione: libro, fascicolo: libro)
    assert_not pivot.valid?
    assert_includes pivot.errors[:fascicolo_id], "non puo' coincidere con la confezione"
  end

  test "validazione uniqueness fascicolo per confezione" do
    confezione = libri(:confezione_fizzy)
    fascicolo  = libri(:fascicolo_uno)
    assert ConfezioneRiga.exists?(confezione: confezione, fascicolo: fascicolo)

    dup = ConfezioneRiga.new(confezione: confezione, fascicolo: fascicolo)
    assert_not dup.valid?
  end

  test "destroy della confezione elimina solo le ConfezioneRiga, non i libri-fascicolo" do
    confezione    = libri(:confezione_fizzy)
    fascicoli_ids = confezione.fascicoli.pluck(:id)
    assert fascicoli_ids.any?

    assert_difference -> { ConfezioneRiga.where(confezione_id: confezione.id).count } => -fascicoli_ids.size do
      assert_no_difference -> { Libro.where(id: fascicoli_ids).count } do
        confezione.destroy!
      end
    end
  end

  test "destroy del fascicolo elimina solo le ConfezioneRiga in cui appare" do
    fascicolo  = libri(:fascicolo_uno)
    confezioni_ids = fascicolo.confezioni.pluck(:id)
    assert confezioni_ids.any?

    assert_difference -> { ConfezioneRiga.where(fascicolo_id: fascicolo.id).count } => -confezioni_ids.size do
      assert_no_difference -> { Libro.where(id: confezioni_ids).count } do
        fascicolo.destroy!
      end
    end
  end
end
