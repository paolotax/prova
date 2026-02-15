module Scuole
  class AdozioniController < ApplicationController
    layout false
    before_action :set_scuola

    def show
      @scope = params[:scope] || "mie"
      base = Adozione.joins(:classe)
                      .where(classe_id: @scuola.classi.select(:id))
                      .includes(:classe)
                      .order(:disciplina, :titolo, "classi.anno_corso", "classi.sezione")

      @adozioni = @scope == "mie" ? base.where(mia: true, da_acquistare: true) : base
    end

    private

    def set_scuola
      @scuola = Current.account.scuole.find(params[:scuola_id])
    end
  end
end
