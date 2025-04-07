class Searches::ClientableController < ApplicationController

  def index
    giro_id = params[:giro_id]
    
    @results = case params[:type]
              when 'Cliente'
                current_user.clienti.search(params[:query])
              when 'ImportScuola'
                scuole = current_user.import_scuole.search(params[:query])
                if giro_id.present?
                  scuole = current_user.import_scuole
                    .where.not(id: Tappa.joins(:giri).where(giri: { id: giro_id }).where(tappable_type: 'ImportScuola').select(:tappable_id))
                    .where.not(id: Giro.find(giro_id).excluded_ids)
                end
                scuole.search(params[:query]).order(:position)
              end

    render partial: 'results', locals: { results: @results }
  end

  # def show
  # end

  # def new
    
  # end

end
