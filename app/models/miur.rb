module Miur
  # Errore di dominio degli import miur:* (soglie CSV, lock occupato, tripwire
  # rollover, anni misti). StandardError, non SystemExit: i rescue generici degli
  # scraper lo catturano e Sidekiq non ritenta condizioni non risolvibili da retry.
  class ImportError < StandardError; end

  def self.table_name_prefix = "miur_"

  # Anno campagna corrente: il massimo pubblicato nell'anagrafe scuole.
  # ATTENZIONE: con miur_scuole vuota restituisce nil e gli scope che lo
  # usano (es. Miur::Adozione.correnti) diventano relation silenziosamente vuote.
  # (Fase 2 lo promuove a value object AnnoScolastico.)
  def self.anno_corrente
    Miur::Scuola.maximum(:anno_scolastico)
  end
end
