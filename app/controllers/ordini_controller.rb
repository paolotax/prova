class OrdiniController < ApplicationController

  before_action :authenticate_user!
  def index
    @documenti = current_user.documenti
      .where('EXTRACT(YEAR FROM data_documento) = 2025')
      .joins(:causale)
      .where(causali: { tipo_movimento: :ordine })
      .includes(:righe)
    @documento_righe = @documenti.map(&:documento_righe).flatten
    @righe = @documento_righe.map(&:riga).flatten

    @clienti = @documenti.map(&:clientable).uniq.sort_by(&:denominazione)
  end
end
