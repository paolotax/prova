module Miur
  def self.table_name_prefix = "miur_"

  # Anno campagna corrente: il massimo pubblicato nell'anagrafe scuole.
  # (Fase 2 lo promuove a value object AnnoScolastico.)
  def self.anno_corrente
    Miur::Scuola.maximum(:anno_scolastico)
  end
end
