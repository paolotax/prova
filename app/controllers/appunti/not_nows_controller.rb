# frozen_string_literal: true

module Appunti
  class NotNowsController < ApplicationController
    include AppuntoScoped

    # POST /appunti/:appunto_id/not_now
    def create
      @appunto.postpone

      respond_to do |format|
        format.turbo_stream { render_appunto_replacement }
        format.html { redirect_back fallback_location: appunti_path }
      end
    end

    # DELETE /appunti/:appunto_id/not_now
    def destroy
      @appunto.resume

      respond_to do |format|
        format.turbo_stream { render_appunto_replacement }
        format.html { redirect_back fallback_location: appunti_path }
      end
    end
  end
end
