class Scuole::Stats
  
  include ActiveModel::Model

  attr_reader :conteggio_scuole, :conteggio_adozioni, :conteggio_classi, :conteggio_marchi


  def initialize(scuole)
    @scuole = scuole
  end

  def stats
    
    @conteggio_scuole   = @scuole.load.count
    @conteggio_classi   = Views::Classe.where(codice_ministeriale: @scuole.map(&:CODICESCUOLA)).load.count
    @conteggio_adozioni = ImportAdozione.where(CODICESCUOLA: @scuole.map(&:CODICESCUOLA)).load.count
    @conteggio_marchi   = ImportAdozione.select(:EDITORE).where(CODICESCUOLA: @scuole.map(&:CODICESCUOLA)).distinct.count
    
    self
  end


end
