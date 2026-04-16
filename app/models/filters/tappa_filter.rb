module Filters
  class TappaFilter < Base
    include TappaFilter::Fields

    def results(base_scope = nil)
      scope = base_scope || ::Tappa.where(account: account || Current.account)

      scope = apply_filter(scope)
      scope = apply_giro(scope)
      scope = apply_scuola(scope)
      scope = apply_date_range(scope)
      scope = apply_giorno(scope)
      scope = apply_area(scope)
      scope = apply_search(scope)
      scope = apply_week_offset(scope)
      scope = apply_sort(scope)

      scope.includes(:tappable, :giri)
    end

    def settimana_info
      return [nil, nil, 0] if week_offset.blank? && filter != "settimana"
      offset = week_offset.to_i
      start = Date.current.beginning_of_week + offset.weeks
      [start, start.end_of_week, offset]
    end

    private

    def apply_filter(scope)
      case filter
      when "oggi"           then scope.di_oggi
      when "domani"         then scope.di_domani
      when "settimana"      then scope.della_settimana(Date.current)
      when "mese"           then scope.del_mese(Date.current)
      when "programmate"    then scope.programmate
      when "completate"     then scope.completate
      when "da_programmare" then scope.da_programmare
      else scope
      end
    end

    def apply_giro(scope)
      if giro_ids.present?
        scope.joins(:giri).where(giri: { id: giro_ids }).distinct
      elsif giro_id.present?
        scope.joins(:giri).where(giri: { id: giro_id }).distinct
      else
        scope
      end
    end

    def apply_scuola(scope)
      return scope if scuola_id.blank?
      scope.where(tappable_type: "Scuola", tappable_id: scuola_id)
    end

    def apply_date_range(scope)
      return scope if data_inizio.blank? || data_fine.blank?
      scope.where(data_tappa: data_inizio..data_fine)
    end

    def apply_giorno(scope)
      return scope if giorno.blank?
      scope.del_giorno(giorno)
    end

    def apply_area(scope)
      return scope if area.blank?
      scope.dell_area(area)
    end

    def apply_search(scope)
      return scope if search.blank?
      scope.search(search)
    end

    def apply_week_offset(scope)
      return scope if week_offset.blank?
      scope.per_settimana(week_offset.to_i)
    end

    def apply_sort(scope)
      case sort
      when "per_data"           then scope.per_data
      when "per_data_desc"      then scope.per_data_desc
      when "per_ordine_e_data"  then scope.per_ordine_e_data
      else scope.order(data_tappa: :asc, position: :asc)
      end
    end
  end
end
