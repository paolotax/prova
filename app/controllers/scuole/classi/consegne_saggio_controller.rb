module Scuole
  module Classi
    class ConsegneSaggioController < ApplicationController
      before_action :set_scuola
      before_action :set_classe

      def create
        @adozione = @classe.adozioni.find(params[:adozione_id])
        @adozione.consegne_saggio.create!(
          account: Current.account,
          user: Current.user,
          tipo: params[:tipo],
          libro: @adozione.libro
        )
        redirect_to scuola_classe_path(@scuola, @classe)
      end

      def destroy
        consegna = @classe.consegne_saggio.find(params[:id])
        consegna.destroy
        redirect_to scuola_classe_path(@scuola, @classe)
      end

      private

      def set_scuola
        @scuola = Current.account.scuole.find(params[:scuola_id])
      end

      def set_classe
        @classe = @scuola.classi.find(params[:classe_id])
      end
    end
  end
end
