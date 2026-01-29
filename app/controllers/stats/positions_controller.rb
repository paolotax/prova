# frozen_string_literal: true

class Stats::PositionsController < ApplicationController
  include StatScoped

  def update
    @stat.update!(position: params[:position].to_i)

    respond_to do |format|
      format.turbo_stream
      format.html { head :ok }
    end
  end
end
