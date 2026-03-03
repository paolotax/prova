module Accounts
  class AreeController < ApplicationController
    def show
      @provincia = params[:provincia]
      account_scuole = Current.account.scuole.where(provincia: @provincia)

      # Plessi e scuole isolate (escludi le pure direzioni dal pluck aree)
      direzione_ids = account_scuole.where.not(direzione_id: nil).select(:direzione_id).distinct
      leaf_scuole = account_scuole.where.not(direzione_id: nil)
        .or(account_scuole.where(direzione_id: nil).where.not(id: direzione_ids))

      # Aree distinte (solo da leaf scuole, non da direzioni composite)
      @aree = leaf_scuole.where.not(area: [nil, "", "__da_pulire__"])
        .distinct.pluck(:area).sort

      # Include area from session (just created, may still be empty)
      new_area = session.delete("new_area_#{@provincia}")
      @aree << new_area if new_area.present? && @aree.exclude?(new_area)

      # Carica tutte le leaf scuole con classi
      all_plessi = account_scuole.where.not(direzione_id: nil).includes(:classi).order(:comune, :denominazione)
      isolated = account_scuole.where(direzione_id: nil).where.not(id: direzione_ids)
        .includes(:classi).order(:comune, :denominazione)
      direzioni_map = account_scuole.where(id: direzione_ids).index_by(&:id)

      # Raggruppa per area → per direzione → gruppi
      @scuole_by_area = build_area_groups(all_plessi, isolated, direzioni_map)

      # Gruppi dai mandati attivi (non disdetti, wildcard) per gradi in zona
      gradi_attivi = Current.account.zone.where(stato: "attiva", provincia: @provincia).pluck(:grado).uniq
      provincia_mandati = Current.account.mandati.includes(:editore)
        .where(provincia: @provincia, grado: gradi_attivi)

      @wildcard_gruppi = provincia_mandati.select { |m| m.area.nil? && !m.disdetta }
        .filter_map { |m| m.editore.gruppo }.uniq.sort

      @gruppi_esclusi_per_area = {}
      @aree.each do |area|
        @gruppi_esclusi_per_area[area] = provincia_mandati
          .select { |m| m.area == area && m.disdetta }
          .filter_map { |m| m.editore.gruppo }.uniq
      end
    end

    private

    def build_area_groups(all_plessi, isolated, direzioni_map)
      groups = Hash.new { |h, k| h[k] = [] }

      # Plessi raggruppati per area, poi per direzione
      all_plessi.group_by { |p| area_key(p.area) }.each do |area_key, plessi|
        plessi.group_by(&:direzione_id).each do |dir_id, dir_plessi|
          groups[area_key] << {
            direzione: direzioni_map[dir_id],
            plessi: dir_plessi
          }
        end
      end

      # Scuole isolate
      isolated.each do |scuola|
        groups[area_key(scuola.area)] << { direzione: nil, plessi: [scuola] }
      end

      # Ordina ogni gruppo per comune, denominazione
      groups.transform_values! do |gruppi|
        gruppi.sort_by { |g| [(g[:direzione] || g[:plessi].first).comune.to_s, (g[:direzione] || g[:plessi].first).denominazione.to_s] }
      end

      groups
    end

    def area_key(area)
      return "__unassigned__" if area.blank?
      return "__da_pulire__" if area == "__da_pulire__"
      area
    end
  end
end
