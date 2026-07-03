module Scuole
  class AdozioniController < ApplicationController
    layout false
    before_action :set_scuola

    def show
      @scope = params[:scope] || "mie"
      base = Adozione.correnti
                      .where(classe_id: @scuola.classi.attive.select(:id))
                      .includes(:classe)
                      .order(:disciplina, "classi.anno_corso", "classi.sezione", :titolo)

      @adozioni = @scope == "mie" ? base.where(mia: true, da_acquistare: true) : base
    end

    private

    def set_scuola
      @scuola = Current.account.scuole.find(params[:scuola_id])
    end
  end
end
