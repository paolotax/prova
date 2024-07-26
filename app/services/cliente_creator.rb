class ClienteCreator

  def create_cliente(cliente)
    
    cliente.denominazione = cliente.denominazione.upcase
    cliente.save
    if cliente.invalid?
      return Result.new(created: false, cliente: cliente)
    end
    # do some stuff here
    Result.new(created: cliente.valid?, cliente: cliente)
  end

  class Result
    attr_reader :cliente
    def initialize(created:, cliente:)
      @created = created
      @cliente = cliente
    end

    def created?
      @created
    end
  end

end
