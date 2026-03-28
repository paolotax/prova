module Api
  module V1
    class PersoneController < ActionController::API
      include Api::TokenAuthenticatable

      before_action :authenticate_api!

      # GET /api/v1/persone
      def index
        scope = Current.account.persone.includes(:scuola, :classi)

        if params[:anno_corso].present?
          anni = params[:anno_corso].split(",").map(&:strip).map(&:to_i)
          scope = scope.joins(:classi).where(classi: { anno_corso: anni }).distinct
        end

        if params[:con_email].present?
          scope = scope.where.not(email: [nil, ""])
        end

        if params[:scuola_id].present?
          scope = scope.where(scuola_id: params[:scuola_id])
        end

        if params[:q].present?
          params[:q].split(/\s+/).each do |word|
            scope = scope.where(
              "persone.cognome ILIKE :q OR persone.nome ILIKE :q", q: "%#{word}%"
            )
          end
        end

        limit = (params[:limit] || 50).to_i.clamp(1, 200)
        persone = scope.order(:cognome, :nome).limit(limit)

        render json: {
          results: persone.map { |p| format_persona(p) },
          count: persone.size
        }
      end

      # POST /api/v1/persone/import
      def import
        importer = Persone::Importer.new(**import_params).import

        status = importer.ok? ? :ok : :unprocessable_entity
        render json: importer.result, status: status
      end

      # POST /api/v1/persone/import_batch
      def import_batch
        persone_data = params.require(:persone).map { |p| p.permit(:cognome, :nome, :email, :cellulare, :telefono, :scuola, :ruolo, classi: []).to_h }
        result = Persone::Importer.import_batch(persone_data)

        render json: result
      end

      private

      def import_params
        params.permit(:cognome, :nome, :email, :cellulare, :telefono, :scuola, :ruolo, classi: []).to_h.symbolize_keys
      end

      def format_persona(persona)
        {
          id: persona.id,
          cognome: persona.cognome,
          nome: persona.nome,
          email: persona.email,
          cellulare: persona.cellulare,
          telefono: persona.telefono,
          scuola: persona.scuola&.denominazione,
          scuola_id: persona.scuola_id,
          classi: persona.classi.map { |c| { id: c.id, display: c.to_combobox_display, anno_corso: c.anno_corso } },
          appuntabile_value: "Persona:#{persona.id}"
        }
      end
    end
  end
end
