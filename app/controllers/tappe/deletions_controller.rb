# frozen_string_literal: true

module Tappe
  class DeletionsController < ApplicationController
    def create
      @tappe = current_user.tappe.where(id: params[:ids])
      giorno = @tappe.first&.data_tappa || Date.current
      count = @tappe.count

      @tappe.destroy_all

      notice = helpers.pluralize(count, "tappa eliminata", "tappe eliminate")

      respond_to do |format|
        format.turbo_stream { flash.now[:notice] = notice }
        format.html { redirect_to giorno_path(giorno), notice: notice }
      end
    end
  end
end
