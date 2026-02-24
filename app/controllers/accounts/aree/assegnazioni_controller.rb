module Accounts
  module Aree
    class AssegnazioniController < ApplicationController
      def create
        provincia = params[:aree_provincia]

        if params[:area_name].present?
          # Crea nuova area vuota — la salviamo in session per mostrarla come colonna
          session["new_area_#{provincia}"] = params[:area_name].strip
          redirect_to accounts_aree_path(provincia: provincia), status: :see_other
          return
        end

        scuola = Current.account.scuole.find(params[:scuola_id])
        area = params[:area].presence

        scuola.update!(area: area)
        # Plessi are updated automatically via the after_update_commit callback

        if area == "__da_pulire__"
          cleanup_scuola(scuola)
          cleanup_zone_vuote(provincia)
          UpdateMieAdozioniJob.perform_later(Current.account)
        end

        redirect_to accounts_aree_path(provincia: provincia), status: :see_other
      end

      private

      def cleanup_scuola(scuola)
        # Elimina plessi senza documenti (se è una direzione)
        if scuola.direzione_id.nil? && scuola.plessi.any?
          scuola.plessi.each { |p| p.destroy unless p.documenti.exists? }
        end
        # Elimina la scuola stessa se non ha documenti
        scuola.destroy unless scuola.documenti.exists?
      end

      def cleanup_zone_vuote(provincia)
        Current.account.zone.where(provincia: provincia, stato: "attiva").find_each do |zona|
          remaining = Current.account.scuole.where(provincia: zona.provincia, grado: zona.grado).count
          if remaining == 0
            Current.account.mandati.where(provincia: zona.provincia, grado: zona.grado).destroy_all
            zona.destroy!
          else
            zona.update!(scuole_count: remaining)
          end
        end
      end
    end
  end
end
