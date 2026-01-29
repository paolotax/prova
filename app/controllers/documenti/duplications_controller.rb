# frozen_string_literal: true

module Documenti
  class DuplicationsController < ApplicationController
    def create
      @documenti = current_account.documenti.where(id: params[:ids])
      @documenti_creati = []

      @documenti.each do |documento|
        nuovo_documento = current_account.documenti.create(
          causale: documento.causale,
          clientable: documento.clientable,
          referente: documento.referente,
          note: documento.note,
          data_documento: Date.current,
          numero_documento: current_account.documenti
                            .where(causale: documento.causale)
                            .where("EXTRACT(YEAR FROM data_documento) = ?", Date.current.year)
                            .maximum(:numero_documento).to_i + 1
        )

        documento.documento_righe.each do |riga|
          nuovo_documento.documento_righe.create(riga: riga.riga.dup)
        end

        @documenti_creati << nuovo_documento
      end

      notice = helpers.pluralize(@documenti_creati.count, "documento duplicato", "documenti duplicati")

      respond_to do |format|
        format.turbo_stream { flash.now[:notice] = notice }
        format.html { redirect_to documenti_path, notice: notice }
      end
    end
  end
end
