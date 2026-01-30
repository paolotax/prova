# frozen_string_literal: true

module Appunti
  class GoldnessesController < ApplicationController
    include AppuntoScoped

    # POST /appunti/:appunto_id/goldness
    def create
      @appunto.ensure_entry!
      @appunto.gild

      respond_to do |format|
        format.turbo_stream { render_appunto_replacement }
        format.html { head :no_content }
      end
    end

    # DELETE /appunti/:appunto_id/goldness
    def destroy
      @appunto.ungild

      respond_to do |format|
        format.turbo_stream { render_appunto_replacement }
        format.html { head :no_content }
      end
    end
  end
end
