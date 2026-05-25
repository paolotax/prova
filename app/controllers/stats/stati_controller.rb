# frozen_string_literal: true

class Stats::StatiController < ApplicationController
  include StatScoped

  def update
    authorize @stat, :update?

    nuovo = params.require(:stato).to_s
    unless Stat::STATI.include?(nuovo)
      redirect_back fallback_location: stats_path, alert: "Stato non valido."
      return
    end

    @stat.update!(stato: nuovo)
    redirect_back fallback_location: stats_path, notice: "Stato aggiornato a #{nuovo}."
  end
end
