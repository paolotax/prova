module Accounts
  class AreeController < ApplicationController
    def show
      @provincia = params[:provincia]
      scuole = Current.account.scuole.where(provincia: @provincia)

      # Get all distinct areas for this provincia (exclude special __da_pulire__)
      @aree = scuole.where.not(area: [nil, "", "__da_pulire__"]).distinct.pluck(:area).sort

      # Include area from session (just created, may still be empty)
      new_area = session.delete("new_area_#{@provincia}")
      @aree << new_area if new_area.present? && @aree.exclude?(new_area)

      # Group direzioni and isolated schools by area
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
      @scuole_by_area["__da_pulire__"] = leaders.select { |s| s.area == "__da_pulire__" }

      # Gruppi dai mandati attivi (non disdetti, wildcard) per gradi in zona
      gradi_attivi = Current.account.zone.where(stato: "attiva", provincia: @provincia).pluck(:grado).uniq
      provincia_mandati = Current.account.mandati.includes(:editore)
        .where(provincia: @provincia, grado: gradi_attivi)

      @wildcard_gruppi = provincia_mandati.select { |m| m.area.nil? && !m.disdetta }
        .filter_map { |m| m.editore.gruppo }.uniq.sort

      # Esclusioni: mandati area-specifici con disdetta
      @gruppi_esclusi_per_area = {}
      @aree.each do |area|
        @gruppi_esclusi_per_area[area] = provincia_mandati
          .select { |m| m.area == area && m.disdetta }
          .filter_map { |m| m.editore.gruppo }.uniq
      end
    end
  end
end
