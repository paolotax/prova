# frozen_string_literal: true

module Scuole
  class BulkTappeController < ApplicationController
    def create
      @scuole = current_account.import_scuole.where(id: params[:ids])
      scuola_ids = @scuole.pluck(:id).uniq

      tappe_create = []

      scuola_ids.each do |scuola_id|
        next if scuola_id.blank?

        tappa = current_user.tappe.find_or_create_by(
          tappable_type: "ImportScuola",
          tappable_id: scuola_id,
          data_tappa: params[:data_tappa],
          user_id: current_user.id,
          titolo: params[:titolo],
          giro_id: params[:giro_id]
        )
        tappe_create << tappa
      end

      notice = helpers.pluralize(tappe_create.count, "tappa aggiunta", "tappe aggiunte")

      respond_to do |format|
        format.turbo_stream { flash.now[:notice] = notice }
        format.html { redirect_to import_scuole_path, notice: notice }
      end
    end
  end
end
