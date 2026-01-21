# frozen_string_literal: true

module Appunti
  class GoldnessesController < ApplicationController
    before_action :set_appunto

    # POST /appunti/:appunto_id/goldness
    def create
      @appunto.mark_golden

      respond_to do |format|
        format.turbo_stream  { render_appunto_replacement }
        format.html { head :no_content }
      end
    end

    # DELETE /appunti/:appunto_id/goldness
    def destroy
      @appunto.unmark_golden

      respond_to do |format|
        format.turbo_stream  { render_appunto_replacement }
        format.html { head :no_content }
      end
    end

    private

    def set_appunto
      @appunto = current_account.appunti.find(params[:appunto_id])
    end

    def render_appunto_replacement
      render turbo_stream: turbo_stream.replace([ @appunto, :container ], partial: "appunti/container", method: :morph, locals: { appunto: @appunto.reload })
    end
  end
end
