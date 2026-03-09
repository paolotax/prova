module Scuole
  class PersoneSearchController < ApplicationController
    include PersoneSearchHelper
    before_action :set_scuola

    def index
      @persone = search_persone(params[:q])

      respond_to do |format|
        format.turbo_stream
      end
    end

    private

    def set_scuola
      @scuola = Scuola.find(params[:scuola_id])
    end

    def search_persone(query)
      return [] if query.blank? || query.length < 2

      limit = 8

      # Prima: persone della scuola corrente
      della_scuola = Current.account.persone
        .where(scuola_id: @scuola.id)
        .ilike_search(query)
        .includes(:scuola, persona_classi: :classe)
        .limit(limit)
        .map { |p| PersonaResult.new(p, stessa_scuola: true) }

      # Poi: persone di altre scuole
      altre = Current.account.persone
        .where.not(scuola_id: @scuola.id)
        .ilike_search(query)
        .includes(:scuola, persona_classi: :classe)
        .limit(limit)
        .map { |p| PersonaResult.new(p, stessa_scuola: false) }

      della_scuola + altre
    end
  end
end
