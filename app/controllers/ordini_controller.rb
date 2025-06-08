class OrdiniController < ApplicationController

  before_action :authenticate_user!
  def index

    status = params[:status] ||= 0

    @documenti = current_user.documenti.where('EXTRACT(YEAR FROM data_documento) = 2025').includes(:righe).where(status: status)
    @documento_righe = @documenti.map(&:documento_righe).flatten
    @righe = @documento_righe.map(&:riga).flatten

    @clienti = @documenti.map(&:clientable).uniq.sort_by(&:denominazione)

    #@ordini = current_user.righe.joins(:documenti).where(documenti: { status: 0 })


  end
end
