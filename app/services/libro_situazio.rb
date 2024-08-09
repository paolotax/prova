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
  end
  
  def venduto
    ordine_cliente + documento_di_trasporto + ddt_fornitore + ordine_scuola + td01 - td04
  end

  def create_libro(libro)
    
    libro.titolo = libro.titolo.upcase
    libro.save
    if libro.invalid?
      return Result.new(created: false, libro: libro)
    end
    # do some stuff here
    Result.new(created: libro.valid?, libro: libro)
  end
  #{"titolo"=>"IN VACANZA CON MAGHETTO PASTICCIONE 1", "codice_isbn"=>"9788883885921", "editore"=>"TREDIECI EDITRICE", "prezzo_in_cents"=>680, "id"=>200, "ordine_cliente"=>nil, "documento_di_trasporto"=>nil, "ddt_fornitore"=>nil, "ordine_scuola"=>29, "td01"=>nil, "td04"=>nil}
  class Result
    attr_reader :libro
    def initialize(created:, libro:)
      @created = created
      @libro = libro
    end

    def created?
      @created
    end
  end

end
