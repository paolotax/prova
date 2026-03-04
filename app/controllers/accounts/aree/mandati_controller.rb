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

        enqueue_area_updates(provincia, area)

        respond_to do |format|
          format.html { redirect_to accounts_aree_path(provincia: provincia), status: :see_other }
          format.turbo_stream do
            render turbo_stream: [
              turbo_stream.remove("mandato-badge-#{area.parameterize}-#{gruppo.parameterize}"),
              turbo_stream.refresh
            ]
          end
        end
      end

      # POST — rimuovi esclusione (ripristina copertura wildcard per area)
      def create
        provincia = params[:aree_provincia]
        area = params[:area]
        gruppo = params[:gruppo]

        Current.account.mandati.joins(:editore)
          .where(provincia: provincia, area: area, disdetta: true, editori: { gruppo: gruppo })
          .delete_all

        enqueue_area_updates(provincia, area)
        redirect_to accounts_aree_path(provincia: provincia), status: :see_other
      end

      private

      def enqueue_area_updates(provincia, area)
        root_ids = Current.account.scuole
          .where(provincia: provincia, area: area)
          .pluck(:direzione_id, :id)
          .map { |dir_id, id| dir_id || id }
          .uniq

        root_ids.each do |id|
          UpdateScuolaMieAdozioniJob.perform_later(Current.account, scuola_id: id)
        end
      end
    end
  end
end
