module Adozioni
  class ComunicateController < ApplicationController
    def index
      @anno_scolastico = params[:anno_scolastico].presence ||
                         scope_base.maximum(:anno_scolastico) ||
                         "202627"

      @comunicate = scope_base.per_anno(@anno_scolastico)
      @editori = @comunicate.distinct.order(:editore).pluck(:editore).compact

      @comunicate = @comunicate.per_editore(params[:editore]) if params[:editore].present?
      @comunicate = @comunicate.where(stato_match: params[:stato_match]) if params[:stato_match].present?
      @comunicate = @comunicate.order(:provincia, :comune, :codicescuola, :anno_corso, :sezioni)

      @totale = @comunicate.count
      @matched = @comunicate.matched.count
      @discrepanze = @comunicate.discrepanze.count
    end

    private

    def scope_base
      Comunicata.for_account(Current.account)
    end
  end
end
