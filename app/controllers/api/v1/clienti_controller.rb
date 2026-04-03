module Api
  module V1
    class ClientiController < ActionController::API
      include Api::TokenAuthenticatable

      before_action :authenticate_api!

      def index
        @clienti = Current.account.clienti.order(denominazione: :asc)
        @clienti = @clienti.search_all_word(params[:q]) if params[:q].present?
        @clienti = @clienti.limit(params[:limit] || 50)
      end

      def show
        @cliente = Current.account.clienti.find(params[:id])
      end

      def update
        @cliente = Current.account.clienti.find(params[:id])

        if @cliente.update(cliente_params)
          render :show
        else
          render json: @cliente.errors, status: :unprocessable_entity
        end
      end

      private

      def cliente_params
        params.require(:cliente).permit(
          :denominazione,
          :partita_iva,
          :codice_fiscale,
          :indirizzo,
          :comune,
          :provincia,
          :cap,
          :email,
          :telefono,
          :pec,
          :indirizzo_telematico
        )
      end
    end
  end
end
