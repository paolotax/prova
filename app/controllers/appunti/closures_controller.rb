# frozen_string_literal: true

module Appunti
  class ClosuresController < ApplicationController
    before_action :set_appunto

    # POST /appunti/:appunto_id/closure
    def create
      @appunto.close

      respond_to do |format|
        format.turbo_stream
        #format.html { redirect_back fallback_location: appunti_path }
      end
    end

    # DELETE /appunti/:appunto_id/closure
    def destroy
      @appunto.reopen

      respond_to do |format|
        format.turbo_stream
        #format.html { redirect_back fallback_location: appunti_path }
      end
    end

    private

    def set_appunto
      @appunto = current_account.appunti.find(params[:appunto_id])
    end
  end
end
