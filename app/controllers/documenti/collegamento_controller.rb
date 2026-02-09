# frozen_string_literal: true

module Documenti
  class CollegamentoController < ApplicationController
    before_action :set_documento

    # POST /documenti/:documento_id/collegamento
    def create
      figlio = current_account.documenti.find(params[:figlio_id])
      @documento.collega_documento_figlio(figlio)

      redirect_to documento_path(@documento), notice: "Documento collegato"
    end

    private

    def set_documento
      @documento = current_account.documenti.find(params[:documento_id])
    end
  end
end
