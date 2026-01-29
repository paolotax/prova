# frozen_string_literal: true

module Tappe
  class DuplicationsController < ApplicationController
    def create
      @tappe = current_user.tappe.where(id: params[:ids])
      @tappe_create = []

      @tappe.each do |tappa|
        nuova_tappa = tappa.dup
        nuova_tappa.data_tappa = params[:data_tappa]
        nuova_tappa.titolo = params[:titolo] if params[:titolo].present?
        nuova_tappa.save

        update_tappa_giri(nuova_tappa, params[:giro_ids]) if params[:giro_ids].present?
        @tappe_create << nuova_tappa
      end

      notice = helpers.pluralize(@tappe_create.count, "tappa duplicata", "tappe duplicate")

      respond_to do |format|
        format.turbo_stream { flash.now[:notice] = notice }
        format.html { redirect_to giorno_path(params[:data_tappa]), notice: notice }
      end
    end

    private

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
