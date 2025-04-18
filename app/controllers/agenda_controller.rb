class AgendaController < ApplicationController

  before_action :authenticate_user!
  
  def index  
    @giorno = params[:giorno]&.to_date || Date.today
    @settimana = helpers.dates_of_week(@giorno)
    # @settimana_precedente = helpers.dates_of_week(@giorno - 7.days)
    @tappe_per_giorno = current_user.tappe.della_settimana(@giorno).group_by(&:data_tappa)
    
    respond_to do |format|
      format.html # Render the full page initially
      format.turbo_stream do
        if params[:direction] == 'prepend'
          render turbo_stream: turbo_stream.prepend("week-container", partial: "agenda/week", locals: { settimana: @settimana, tappe_per_giorno: @tappe_per_giorno })
        else
          render turbo_stream: turbo_stream.append("week-container", partial: "agenda/week", locals: { settimana: @settimana, tappe_per_giorno: @tappe_per_giorno })
        end
      end
    end
  end

  def show
    @giorno = params[:giorno] ? Date.parse(params[:giorno]) : Date.today
    @scuole = current_user.import_scuole
                .includes(:appunti_da_completare)
                .where(id: current_user.tappe.del_giorno(@giorno).where(tappable_type: "ImportScuola").pluck(:tappable_id))        
    @clienti = current_user.clienti
                .where(id: current_user.tappe.del_giorno(@giorno).where(tappable_type: "Cliente").pluck(:tappable_id))
    
    @tappe = current_user.tappe.del_giorno(@giorno).includes(:tappable, :giri).order(:position)
  end

  def mappa 
    @giorno = params[:giorno] ? Date.parse(params[:giorno]) : Date.today
    
    @tappe = current_user.tappe.del_giorno(@giorno).includes(:tappable, :giri).order(:position)

    @indirizzi = @tappe.map do |t|
      {
        latitude: t.latitude,
        longitude: t.longitude
      }
    end

    @waypoints = @tappe.map do |indirizzo|
      [
        indirizzo.longitude,
        indirizzo.latitude,
        indirizzo.tappable.denominazione,
        indirizzo.tappable.comune,
        indirizzo.tappable_type == "ImportScuola" ? indirizzo.tappable_id : nil
      ]
    end
  end

  def slideover
    @giorno = params[:giorno] ? Date.parse(params[:giorno]) : Date.today
  end

end
