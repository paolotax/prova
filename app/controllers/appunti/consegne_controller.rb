# frozen_string_literal: true

module Appunti
  class ConsegneController < ApplicationController
    before_action :set_appunto

    # POST /appunti/:appunto_id/consegna
    def create
      @appunto.mark_consegnato

      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.replace(dom_id(@appunto, :container), partial: "appunti/container", locals: { appunto: @appunto }) }
        format.html { redirect_back fallback_location: appunti_path }
      end
    end

    # DELETE /appunti/:appunto_id/consegna
    def destroy
      @appunto.unmark_consegnato

      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.replace(dom_id(@appunto, :container), partial: "appunti/container", locals: { appunto: @appunto }) }
        format.html { redirect_back fallback_location: appunti_path }
      end
    end

    private

    def set_appunto
      @appunto = current_account.appunti.find(params[:appunto_id])
    end
  end
end
