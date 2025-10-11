# == Schema Information
#
# Table name: tipi_scuole
#
#  id         :bigint           not null, primary key
#  grado      :string
#  tipo       :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#

class TipoScuola < ApplicationRecord
  
  belongs_to :import_scuola, primary_key: "DESCRIZIONETIPOLOGIAGRADOISTRUZIONESCUOLA", foreign_key: "tipo"

  GRADI = [["infanzia", "I"], ["primaria", "E"], ["secondaria I grado", "M"], ["secondaria II grado", "N"], ["altro", "altro"]]

  # Metodo per popolare la tabella tipi_scuole con i tipi di scuola presenti che non hanno un grado associato
  def self.orfani
    orfani = ImportScuola.select(:DESCRIZIONETIPOLOGIAGRADOISTRUZIONESCUOLA).distinct.where('NOT EXISTS (:tipi_scuole)', 
                        tipi_scuole: TipoScuola.select('1').where('tipi_scuole.tipo = import_scuole."DESCRIZIONETIPOLOGIAGRADOISTRUZIONESCUOLA"')
                      )
    orfani.each do |o|
      TipoScuola.create!(tipo: o.DESCRIZIONETIPOLOGIAGRADOISTRUZIONESCUOLA, grado: 'altro')
    end

  end

end
