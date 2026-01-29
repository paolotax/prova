# frozen_string_literal: true

module Documenti
  class DeletionsController < ApplicationController
    def create
      @ids = params[:ids]
      @figli_ids = current_account.documenti.where(documento_padre_id: @ids).pluck(:id).uniq
      @documenti = current_account.documenti.where(id: @ids)

      count = @documenti.count
      @documenti.destroy_all

      notice = helpers.pluralize(count, "documento eliminato", "documenti eliminati")

      respond_to do |format|
        format.turbo_stream { flash.now[:notice] = notice }
        format.html { redirect_to documenti_path, notice: notice }
      end
    end
  end
end
