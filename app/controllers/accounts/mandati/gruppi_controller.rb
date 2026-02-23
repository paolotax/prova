module Accounts
  module Mandati
    class GruppiController < ApplicationController
      before_action :authenticate_user!

      def destroy
        bulk_scope.destroy_all
        replace_mandati_list
      end

      private

      def bulk_scope
        scope = Current.account.mandati
          .joins(:editore)
          .where(provincia: params[:provincia], editori: { gruppo: params[:id] })
        scope = scope.where(grado: params[:grado]) if params[:grado].present?
        scope
      end

      def replace_mandati_list
        @mandati = Current.account.mandati.includes(:editore).order("editori.gruppo, editori.editore")

        respond_to do |format|
          format.turbo_stream { render turbo_stream: turbo_stream.replace("account-editori", partial: "mandati/mandati_list", method: :morph, locals: { mandati: @mandati }) }
          format.html { redirect_to configurazione_path, notice: "Gruppo eliminato." }
        end
      end
    end
  end
end
