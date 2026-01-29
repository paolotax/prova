# frozen_string_literal: true

class Documenti::NumeriController < ApplicationController
  # GET /documenti/numero?causale_id=X
  def show
    causale = Causale.find(params[:causale])
    clientable_type = causale.clientable_type&.camelize || "Cliente"

    anno_corrente = Date.current.year
    ultimo_documento = current_account.documenti
      .where(causale: params[:causale])
      .where("EXTRACT(YEAR FROM data_documento) = ?", anno_corrente)
      .maximum(:numero_documento)

    numero_documento = (ultimo_documento || 0) + 1

    render json: {
      numero_documento: numero_documento,
      clientable_type: clientable_type
    }
  end
end
