class LibroSituazio

  include ActiveModel::Model
  
  attr_accessor :id, :titolo, :categoria, :codice_isbn, :editore, :prezzo_in_cents, :ordine_cliente, :documento_di_trasporto, :ddt_fornitore, :ordine_scuola, :td01, :td04, :giacenza

  def initialize(attributes = {})
    super
    @imported_count = 0
    @updated_count = 0
    @errors_count = 0
    @ordine_cliente = ordine_cliente || 0
    @documento_di_trasporto = documento_di_trasporto || 0
    @ddt_fornitore = ddt_fornitore || 0
    @ordine_scuola = ordine_scuola || 0
    @td01 = td01 || 0
    @td04 = td04 || 0
    @giacenza = giacenza || 0
  end
  
  def venduto
    ordine_cliente + documento_di_trasporto + ddt_fornitore + ordine_scuola + td01 - td04
  end

  def in_ordine
    @ordine_scuola + @ordine_cliente
  end


end
