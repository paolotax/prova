class Searches::ClientableController < ApplicationController

  def index
    giro_id = params[:giro_id]

    @results = case params[:type]
              when 'Cliente'
                current_user.clienti.search(params[:query])
              when 'Scuola'
                scuole = current_account.scuole.search_all_word(params[:query])
                if giro_id.present?
                  scuole = current_account.scuole
                    .where.not(id: Tappa.joins(:giri).where(giri: { id: giro_id }).where(tappable_type: 'Scuola').select(:tappable_id))
                    .where.not(id: Giro.find(giro_id).excluded_ids)
                end
                scuole.search_all_word(params[:query]).order(:posizione)
              end

    render partial: 'results', locals: { results: @results }
  end

end
