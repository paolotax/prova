# frozen_string_literal: true

module Documenti
  class PagamentiController < ApplicationController
    before_action :set_documento

    # POST /documenti/:documento_id/pagamento
    def create
      @documento.mark_pagato(
        pagato_il: parsed_date(:pagato_il),
        tipo_pagamento: params[:tipo_pagamento]
      )

      respond_to do |format|
        format.turbo_stream { render_container_replacement }
        format.html { redirect_back fallback_location: documento_path(@documento) }
      end
    end

    # DELETE /documenti/:documento_id/pagamento
    def destroy
      @documento.unmark_pagato

      respond_to do |format|
        format.turbo_stream { render_container_replacement }
        format.html { redirect_back fallback_location: documento_path(@documento) }
      end
    end

    private

    def set_documento
      @documento = current_account.documenti.find(params[:documento_id])
    end

    def parsed_date(param)
      return nil unless params[param].present?
      Date.parse(params[param])
    rescue ArgumentError
      Date.today
    end

    def render_container_replacement
      render turbo_stream: turbo_stream.replace(
        dom_id(@documento, :container),
        partial: "documenti/container",
        locals: { documento: @documento }
      )
    end
  end
end
