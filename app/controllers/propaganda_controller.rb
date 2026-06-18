class PropagandaController < ApplicationController
  include FilterScoped

  FILTER_PARAMS = [province: [], aree: [], giro_ids: [], terms: []].freeze

  def index
    @propaganda = Propaganda.corrente(user: current_user)
    @riepilogo = @propaganda&.riepilogo
    @andamento = @propaganda ? @propaganda.andamento(scuole_filtrate) : []
  end

  private

  # Scuole della propaganda, intersecate col filtro province/area/ricerca.
  def scuole_filtrate
    @filter.scuole.where(id: @propaganda.bolle_visione.select(:scuola_id))
  end

  # Override FilterScoped convention: PropagandaController -> PropagandaFilter
  def filter_class
    ::Filters::PropagandaFilter
  end

  def filtering_class
    ::Filters::PropagandaFilter::Filtering
  end
end
