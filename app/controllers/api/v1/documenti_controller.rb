module Api
  module V1
    class DocumentiController < ActionController::API
      include Api::TokenAuthenticatable

      before_action :authenticate_api!

      # POST /api/v1/documenti
      def create
        creator = Documenti::Creator.new(**creator_params)
        creator.create

        if creator.ok?
          render json: creator.result, status: :created
        else
          render json: creator.result, status: :unprocessable_entity
        end
      end

      private

      def creator_params
        {
          clientable_value: params[:clientable_value],
          causale_nome: params[:causale],
          note: params[:note],
          righe_params: Array(params[:righe]).map { |r|
            r.permit(:libro_id, :quantita, :sconto, :prezzo_cents, :titolo, :codice_isbn).to_h.symbolize_keys
          }
        }
      end
    end
  end
end
