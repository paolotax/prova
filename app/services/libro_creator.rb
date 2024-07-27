class LibroCreator

  def create_libro(libro)
    
    libro.titolo = libro.titolo.upcase
    libro.save
    if libro.invalid?
      return Result.new(created: false, libro: libro)
    end
    # do some stuff here
    Result.new(created: libro.valid?, libro: libro)
  end

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
