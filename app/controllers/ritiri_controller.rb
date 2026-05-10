class RitiriController < Ritiri::BaseController
  def show
    @ritiro = Ritiro.new(@scuola)
  end
end
