class AgendaController < ApplicationController
  

  def index

    Groupdate.week_start = :monday

    @giorno = params[:giorno]&.to_date || Date.today
    @settimana = helpers.dates_of_week(@giorno)

    @tappe_per_giorno = current_user.tappe.della_settimana(@giorno).group_by(&:data_tappa)

  end

  def show

    @giorno = params[:giorno] ? Date.parse(params[:giorno]) : Date.today


    @scuole = current_user.import_scuole
                .includes(:appunti_da_completare)
                .where(id: current_user.tappe.del_giorno(@giorno).where(tappable_type: "ImportScuola").pluck(:tappable_id))        
    @clienti = current_user.clienti
                .where(id: current_user.tappe.del_giorno(@giorno).where(tappable_type: "Cliente").pluck(:tappable_id))
    
    @tappe = current_user.tappe.del_giorno(@giorno).includes(:tappable, :giro).order(:position)

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
      ]
    end

    @appunti_del_giorno = current_user.appunti.da_completare.nel_baule_del_giorno(@giorno)
                                .with_attached_attachments
                                .with_attached_image
                                .with_rich_text_content
                                .includes(:import_scuola)
                   
  end
end
