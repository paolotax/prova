# == Schema Information
#
# Table name: causali
#
#  id                 :bigint           not null, primary key
#  causale            :string
#  causali_successive :json
#  clientable_type    :string
#  magazzino          :string
#  movimento          :integer
#  priorita           :integer          default(0)
#  stati_successivi   :json
#  stato_iniziale     :string
#  tipo_movimento     :integer
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#
# Indexes
#
#  index_causali_on_priorita        (priorita)
#  index_causali_on_stato_iniziale  (stato_iniziale)
#

class Causale < ApplicationRecord

  enum :tipo_movimento, { ordine: 0, vendita: 1, carico: 2 }

  enum :movimento, { entrata: 0, uscita: 1 }

  validates :causale, presence: true
  validates :tipo_movimento, presence: true
  validates :movimento, presence: true
  validates :magazzino, presence: true

  # PostgreSQL supporta nativamente JSON, non serve serialize
  # serialize :stati_successivi, type: Array, coder: JSON
  # serialize :causali_successive, type: Array, coder: JSON

  def to_s
    causale
  end

  def to_combobox_display
    causale # or `title`, `to_s`, etc.
  end

  def descrizione_causale
    if causale == "TD01"
      "TD01 - Fattura"
    elsif causale == "TD04"
      "TD04 - Nota di credito"
    elsif causale == "TD24"
      "TD24 - Fattura"
    else
      causale
    end
  end

  # Workflow methods
  def causali_successive_records
    return Causale.none if causali_successive.blank?
    Causale.where(id: causali_successive).or(Causale.where(causale: causali_successive))
  end

  def puo_generare?(causale_target)
    causali_successive.include?(causale_target.id) ||
      causali_successive.include?(causale_target.causale)
  end

  def aggiungi_causale_successiva(causale_target)
    causali_successive << causale_target.id unless causali_successive.include?(causale_target.id)
    save
  end

  def rimuovi_causale_successiva(causale_target)
    causali_successive.delete(causale_target.id)
    causali_successive.delete(causale_target.causale)
    save
  end
end
