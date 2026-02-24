module Accounts
  class AreeController < ApplicationController
    def show
      @provincia = params[:provincia]
      scuole = Current.account.scuole.where(provincia: @provincia)

      # Get all distinct areas for this provincia
      @aree = scuole.where.not(area: [nil, ""]).distinct.pluck(:area).sort

      # Group direzioni and isolated schools by area
      # (plessi are not shown — they follow their direzione)
      leaders = scuole.where(direzione_id: nil)
        .or(scuole.direzioni)
        .distinct
        .includes(:plessi)
        .order(:comune, :denominazione)

      @scuole_by_area = {}
      @scuole_by_area["__unassigned__"] = leaders.select { |s| s.area.blank? }
      @aree.each do |area|
        @scuole_by_area[area] = leaders.select { |s| s.area == area }
      end
    end
  end
end
