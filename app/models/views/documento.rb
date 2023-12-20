# == Schema Information
#
# Table name: view_documenti
#
#  id                   :text             primary key
#  fornitore            :string
#  iva_fornitore        :string
#  cliente              :string
#  iva_cliente          :string
#  tipo_documento       :string
#  numero_documento     :string
#  data_documento       :date
#  quantita_totale      :bigint
#  importo_netto_totale :float
#  totale_documento     :float
#  conto                :text
#  check                :float
#
class Views::Documento < ApplicationRecord

    
    include PgSearch::Model
    
    pg_search_scope :search_any_word,
                  against: [ :tipo_documento, :numero_documento, :data_documento, :cliente, :fornitore ],
                  using: {
                    tsearch: { any_word: false, prefix: true }
                  }

    self.primary_key = "id"

    def righe
        Views::Riga.where(numero_documento: self.numero_documento,
                          data_documento: self.data_documento,
                          fornitore: self.fornitore).order(:riga)
    end

    scope :trova, -> (query) { where("cliente ILIKE ? OR fornitore ILIKE ? OR numero_documento ILIKE ?", "%#{query}%", "%#{query}%", "%#{query}%") }


end
