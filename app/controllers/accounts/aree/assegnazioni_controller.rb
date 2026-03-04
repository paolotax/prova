module Accounts
  module Aree
    class AssegnazioniController < ApplicationController
      def create
        provincia = params[:aree_provincia]

        if params[:area_name].present?
          session["new_area_#{provincia}"] = params[:area_name].strip
          redirect_to accounts_aree_path(provincia: provincia), status: :see_other
          return
        end

        scuola = Current.account.scuole.find(params[:scuola_id])
        area = params[:area].presence

        scuola.update!(area: area)

        if scuola.direzione_id.present?
          # Plesso singolo: aggiorna il sommario area sulla direzione
          sync_direzione_area(scuola.direzione)
        elsif scuola.plessi.any?
          # Direzione trascinata: aggiorna area su tutti i plessi
          scuola.plessi.update_all(area: area)
        end

        if area == "__da_pulire__"
          cleanup_scuola(scuola)
          cleanup_zone_vuote(provincia)
          UpdateMieAdozioniJob.perform_later(Current.account, provincia: provincia)
        else
          UpdateScuolaMieAdozioniJob.perform_later(Current.account, scuola_id: scuola.id)
        end

        cleanup_mandati_aree_vuote(provincia)

        respond_to do |format|
          format.html { redirect_to accounts_aree_path(provincia: provincia), status: :see_other }
          format.turbo_stream { head :ok }
        end
      end

      private

      def sync_direzione_area(direzione)
        plessi_areas = direzione.plessi.pluck(:area).compact_blank.uniq.sort
        direzione.update_column(:area, plessi_areas.join(", ").presence)
      end

      def cleanup_scuola(scuola)
        if scuola.direzione_id.nil? && scuola.plessi.any?
          scuola.plessi.each { |p| p.destroy unless p.documenti.exists? }
        end
        scuola.destroy unless scuola.documenti.exists?
      end

      # Rimuove mandati disdetti per aree che non hanno più scuole
      def cleanup_mandati_aree_vuote(provincia)
        aree_attive = Current.account.scuole.where(provincia: provincia)
          .where.not(area: [nil, "", "__da_pulire__"])
          .distinct.pluck(:area)
        Current.account.mandati.where(provincia: provincia, disdetta: true)
          .where.not(area: [nil] + aree_attive)
          .delete_all
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
