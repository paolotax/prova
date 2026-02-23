module Accounts
  module Mandati
    class DisdettaController < ApplicationController
      before_action :authenticate_user!
      before_action :set_mandato

      def create
        @mandato.update!(disdetta: true)
        replace_mandati_list
      end

      def destroy
        @mandato.update!(disdetta: false)
        replace_mandati_list
      end

      private

      def set_mandato
        @mandato = Current.account.mandati.find(params[:mandato_id])
      end

      def replace_mandati_list
        @mandati = Current.account.mandati.includes(:editore).order("editori.gruppo, editori.editore")

        respond_to do |format|
          format.turbo_stream { render turbo_stream: turbo_stream.replace("account-editori", partial: "accounts/mandati/mandati_list", method: :morph, locals: { mandati: @mandati }) }
          format.html { redirect_to configurazione_path }
        end
      end
    end
  end
end
