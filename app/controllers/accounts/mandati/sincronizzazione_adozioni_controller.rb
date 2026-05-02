module Accounts
  module Mandati
    class SincronizzazioneAdozioniController < ApplicationController
      before_action :authenticate_user!

      def create
        RebuildAccountAdozioniJob.perform_later(Current.account)

        respond_to do |format|
          format.turbo_stream { render turbo_stream: [] }
          format.html { redirect_to accounts_configurazione_path, notice: "Aggiornamento adozioni in corso..." }
        end
      end
    end
  end
end
