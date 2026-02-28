module Giri
  class TappeController < ApplicationController
    before_action :authenticate_user!
    before_action :set_giro

    def create
      schools = @giro.filter_schools(scuole_for_giro)
      created_count = 0

      schools.each do |scuola|
        next if @giro.tappe.exists?(tappable: scuola)

        tappa = current_user.tappe.create!(
          tappable: scuola,
          account: Current.account,
          data_tappa: nil
        )
        tappa.tappa_giri.create!(giro: @giro)
        created_count += 1
      end

      redirect_to giro_path(@giro), notice: "#{created_count} tappe create."
    end

    private

    def set_giro
      @giro = current_user.giri.find(params[:giro_id])
    end

    def scuole_for_giro
      current_account.scuole.where(grado: "E")
    end
  end
end
