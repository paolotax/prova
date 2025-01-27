module Avatar
  class StackedLibriComponent < ViewComponent::Base
    def initialize(libri:, limit: 3)
      @libri = libri
      @limit = limit
    end

    private

    def libri_da_mostrare
      @libri.first(@limit)
    end

    def altri_libri
      return 0 if @libri.size <= @limit
      @libri.size - @limit
    end
  end
end 