class AgendaController < ApplicationController
  def show

    Groupdate.week_start = :monday

    @giorno = params[:giorno]&.to_date || Date.today
    @settimana = helpers.dates_of_week(@giorno)

    @tappe_per_giorno = current_user.tappe.della_settimana(@giorno).group_by(&:data_tappa)
  end
end
