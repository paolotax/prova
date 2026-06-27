class PropagandaController < ApplicationController
  include FilterScoped

  FILTER_PARAMS = [province: [], aree: [], giro_ids: [], terms: []].freeze

  def index
    @propaganda = Propaganda.corrente(user: current_user)
    @riepilogo = @propaganda&.riepilogo
    @stato = params[:stato].presence
    andamento = @propaganda ? @propaganda.andamento(scuole_filtrate) : []
    @conteggi_stato = conteggi_stato(andamento)
    @andamento = filtra_per_stato(andamento)
    @tappe_senza_bolla = @propaganda ? @propaganda.tappe_senza_bolla : []
  end

  private

  # Conteggi per i tab di stato (calcolati sull'andamento non filtrato).
  def conteggi_stato(andamento)
    {
      "tutte" => andamento.size,
      "da_avviare" => andamento.count(&:da_avviare?),
      "parziale" => andamento.count(&:parziale?),
      "completate" => andamento.count(&:completata?)
    }
  end

  # Filtra l'andamento per i tab sopra la lista.
  #   da_avviare → scuole con ritiro mai avviato (tutto da ritirare)
  #   parziale   → scuole ritirate solo in parte (restano alcuni libri)
  #   completate → scuole senza più libri da ritirare
  def filtra_per_stato(andamento)
    case @stato
    when "da_avviare"
      andamento.select(&:da_avviare?)
    when "parziale"
      andamento.select(&:parziale?)
    when "completate"
      andamento.select(&:completata?)
    else
      andamento
    end
  end

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
