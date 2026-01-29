# frozen_string_literal: true

module Tappe
  class BulkUpdatesController < ApplicationController
    def update
      @tappe = current_user.tappe.where(id: params[:ids])

      @tappe.each do |tappa|
        tappa.update(bulk_params.compact_blank)
        update_tappa_giri(tappa, params[:giro_ids]) if params[:giro_ids].present?
      end

      notice = "#{@tappe.count} tappe aggiornate"

      respond_to do |format|
        format.turbo_stream { flash.now[:notice] = notice }
        format.html { redirect_to giorno_path(params[:data_tappa]), notice: notice }
      end
    end

    private

    def bulk_params
      params.permit(:data_tappa, :titolo)
    end

    def update_tappa_giri(tappa, giro_ids)
      return if giro_ids.blank?

      giro_ids_string = giro_ids.is_a?(Array) ? giro_ids.join(",") : giro_ids.to_s
      giro_ids_array = giro_ids_string.split(",").map(&:to_i)

      tappa.tappa_giri.destroy_all
      giro_ids_array.each do |giro_id|
        tappa.tappa_giri.create(giro_id: giro_id)
      end
    end
  end
end
