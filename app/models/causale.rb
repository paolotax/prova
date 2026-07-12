# == Schema Information
#
# Table name: causali
#
#  id                 :bigint           not null, primary key
#  causale            :string
#  causali_successive :json
#  clientable_types   :json             not null
#  gestione_consegna  :boolean          default(TRUE), not null
#  gestione_pagamento :boolean          default(TRUE), not null
#  magazzino          :string
#  mostra_importo     :boolean          default(TRUE), not null
#  movimento          :integer
#  priorita           :integer          default(0)
#  tipo_movimento     :integer
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#
# Indexes
#
#  index_causali_on_priorita  (priorita)
#

class Causale < ApplicationRecord

  enum :tipo_movimento, { ordine: 0, vendita: 1, carico: 2 }

  enum :movimento, { entrata: 0, uscita: 1 }

  enum :magazzino, { vendita: "vendita", campionario: "campionario" }, prefix: :magazzino

  # Effetto fisico sul magazzino: entrata carica (+1), uscita scarica (-1).
  # Unica fonte del segno: Giacenza, Saldo e Movimenti derivano da qui.
  SEGNO_SQL = "CASE causali.movimento WHEN 0 THEN 1 ELSE -1 END".freeze

  CONTESTI = [ "Vendite", "Fornitori", "Campionario" ].freeze

  # Tipi di destinatario per cui una causale può essere pertinente ([] = tutti)
  CLIENTABLE_TYPES = [ "Cliente", "Scuola", "Classe", "Persona" ].freeze

  def self.per_contesto(in_testa: nil)
    order(:causale).group_by(&:contesto)
      .sort_by { |contesto, _| [ contesto == in_testa ? 0 : 1, CONTESTI.index(contesto) ] }
  end

  # I form inviano gli array json con un hidden vuoto per permettere lo svuotamento
  normalizes :clientable_types, :causali_successive,
    with: ->(value) { Array(value).compact_blank }

  def segno
    entrata? ? 1 : -1
  end

  def contesto
    if magazzino_campionario?
      "Campionario"
    elsif carico?
      "Fornitori"
    else
      "Vendite"
    end
  end

  validates :causale, presence: true
  validates :tipo_movimento, presence: true
  validates :movimento, presence: true
  validates :magazzino, presence: true

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

  # Trova le causali che hanno `causale` tra le loro causali_successive (inverso)
  def self.predecessori_di(causale)
    Causale.all.select { |c|
      c.causali_successive.map(&:to_s).include?(causale.id.to_s) ||
      c.causali_successive.map(&:to_s).include?(causale.causale.to_s)
    }
  end

  # Workflow methods
  def causali_successive_records
    return Causale.none if causali_successive.blank?
    Causale.where(id: causali_successive).or(Causale.where(causale: causali_successive))
  end

  def puo_generare?(causale_target)
    causali_successive.map(&:to_s).include?(causale_target.id.to_s) ||
      causali_successive.map(&:to_s).include?(causale_target.causale.to_s)
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
