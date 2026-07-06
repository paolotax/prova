class Scuole::Stats
  
  include ActiveModel::Model

  attr_reader :conteggio_scuole, :conteggio_adozioni, :conteggio_classi, :conteggio_marchi


  def initialize(scuole)
    @scuole = scuole
  end

  def stats
    
    @conteggio_scuole   = @scuole.load.count
    @conteggio_classi   = Views::Classe.where(codice_ministeriale: @scuole.map(&:CODICESCUOLA)).load.count
    @conteggio_adozioni = Miur::Adozione.per_anno("202526").where(codicescuola: @scuole.map(&:CODICESCUOLA)).load.count
    @conteggio_marchi   = Miur::Adozione.per_anno("202526").select(:editore).where(codicescuola: @scuole.map(&:CODICESCUOLA)).distinct.count
    
    self
  end


end
