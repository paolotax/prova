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
    render inline: turbo_frame_error("Errore di sicurezza: #{e.message}"), layout: false
  rescue StandardError => e
    Rails.logger.error("Stat execution error: #{e.message}")
    render inline: turbo_frame_error("Errore nell'esecuzione della query: #{e.message}"), layout: false
  end

  private

  def turbo_frame_error(message)
    %(<turbo-frame id="stat_results">
      <div class="panel txt-negative" style="padding: var(--block-space);">#{ERB::Util.html_escape(message)}</div>
    </turbo-frame>)
  end
end
