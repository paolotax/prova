# frozen_string_literal: true

module Documenti
  class DeletionsController < ApplicationController
    def create
      @entries = current_account.entries.documenti.where(id: params[:ids])
      @entry_ids = @entries.pluck(:id)
      documento_ids = @entries.pluck(:entryable_id)

      @figli_ids = current_account.documenti.where(documento_padre_id: documento_ids).pluck(:id).uniq

      count = @entries.count
      @entries.destroy_all

      notice = helpers.pluralize(count, "documento eliminato", "documenti eliminati")

      respond_to do |format|
        format.turbo_stream { flash.now[:notice] = notice }
        format.html { redirect_to documenti_path, notice: notice }
      end
    end
  end
end
