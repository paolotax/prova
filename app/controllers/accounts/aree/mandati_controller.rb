module Accounts
  module Aree
    class MandatiController < ApplicationController
      # DELETE — escludi gruppo da area (crea mandati disdetta area-specifici)
      def destroy
        provincia = params[:aree_provincia]
        area = params[:area]
        gruppo = params[:gruppo]

        # Solo gli editori che ho già come mandato wildcard in questa provincia
        wildcard_mandati = Current.account.mandati.includes(:editore)
          .where(provincia: provincia, area: nil, disdetta: false)
          .select { |m| m.editore.gruppo == gruppo }

        wildcard_mandati.each do |wm|
          mandato = Current.account.mandati.find_or_initialize_by(
            editore_id: wm.editore_id, provincia: provincia, grado: wm.grado, area: area
          )
          mandato.disdetta = true
          mandato.save!
        end

        UpdateMieAdozioniJob.perform_later(Current.account)
        redirect_to accounts_aree_path(provincia: provincia), status: :see_other
      end

      # POST — rimuovi esclusione (ripristina copertura wildcard per area)
      def create
        provincia = params[:aree_provincia]
        area = params[:area]
        gruppo = params[:gruppo]

        Current.account.mandati.joins(:editore)
          .where(provincia: provincia, area: area, disdetta: true, editori: { gruppo: gruppo })
          .destroy_all

        UpdateMieAdozioniJob.perform_later(Current.account)
        redirect_to accounts_aree_path(provincia: provincia), status: :see_other
      end
    end
  end
end
