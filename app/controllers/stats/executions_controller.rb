# frozen_string_literal: true

class Stats::ExecutionsController < ApplicationController
  include StatScoped

  def show
    authorize @stat, :execute?

    @miei_editori = Current.account.mandati.includes(:editore).map { |m| m.editore.editore }
    @result = @stat.execute(current_user)
    @raggruppamento = @result.group_by do |c|
      fields = @stat.raggruppa
      fields.map { |f| c[f] }
    end

    respond_to do |format|
      format.html
      format.xlsx do
        safe_titolo = @stat.titolo.to_s.parameterize(separator: "_")
        filename = "#{@stat.categoria}_#{safe_titolo}.xlsx"
        response.headers["Content-Disposition"] = "attachment; filename=\"#{filename}\""
      end
    end
  rescue SecurityError => e
    redirect_to stats_path, alert: "Errore di sicurezza: #{e.message}"
  rescue StandardError => e
    Rails.logger.error("Stat execution error: #{e.message}")
    redirect_to stat_path(@stat), alert: "Errore nell'esecuzione della query: #{e.message}"
  end
end
