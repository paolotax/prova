class AgendaController < ApplicationController
  def show

    @settimana = current_user.tappe.della_settimana(Date.today).group_by_day(:data_tappa).count
    
    @tappe_per_giorno = current_user.tappe.della_settimana(Date.today).group_by_day { |t| t.data_tappa }
  end
end
