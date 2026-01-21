# frozen_string_literal: true

module Appunti
  class ClosuresController < ApplicationController
    include AppuntoScoped

    # POST /appunti/:appunto_id/closure
    def create
      @appunto.close

      respond_to do |format|
        format.turbo_stream { render_appunto_replacement }
        format.html { redirect_back fallback_location: appunti_path }
      end
    end

    # DELETE /appunti/:appunto_id/closure
    def destroy
      @appunto.reopen

      respond_to do |format|
        format.turbo_stream { render_appunto_replacement }
        format.html { redirect_back fallback_location: appunti_path }
      end
    end
  end
end
