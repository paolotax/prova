# frozen_string_literal: true

class Stats::ExecutionsController < ApplicationController
  include StatScoped

  def show
    @miei_editori = current_user.miei_editori
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
  end
end
