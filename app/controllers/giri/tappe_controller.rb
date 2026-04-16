class Giri::TappeController < ApplicationController
  before_action :authenticate_user!
  before_action :set_giro

  # GET /giri/:giro_id/genera_tappe
  def new
    existing_ids = @giro.tappe.where(tappable_type: "Scuola").pluck(:tappable_id).map(&:to_s).to_set
    base_scuole = Current.scuole
      .where.not(id: Scuola.unscoped.select(:direzione_id).where.not(direzione_id: nil))
      .where.not(id: existing_ids)
      .includes(:direzione)
      .order(:posizione)

    @scuole = base_scuole.non_scartate
    @scuole_scartate = base_scuole.scartate_da_utente
    @gerarchia = build_gerarchia(@scuole)
  end

  # POST /giri/:giro_id/genera_tappe
  def create
    selected_ids = Array(params[:school_ids]).map(&:to_s)

    count = 0
    selected_ids.each do |school_id|
      tappa = current_user.tappe.create!(
        tappable_type: "Scuola",
        tappable_id: school_id,
        account: Current.account,
        data_tappa: nil
      )
      tappa.tappa_giri.create!(giro: @giro)
      count += 1
    end

    @tappe_per_area = planner_tappe_per_area
    @planner_total = @tappe_per_area.flat_map { |_, dirs| dirs.flat_map(&:last) }.size

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to giro_path(@giro), notice: "#{count} tappe generate." }
    end
  end

  # POST /giri/:giro_id/copia_tappe
  def copy
    source = current_user.giri.find(params[:source_giro_id])
    existing_codes = @giro.tappe.where(tappable_type: "Scuola")
      .joins("INNER JOIN scuole ON tappe.tappable_id = scuole.id")
      .pluck("scuole.codice_ministeriale").compact.to_set

    # Lookup scuole dell'account corrente per codice_ministeriale
    scuole_by_codice = Current.scuole.where.not(codice_ministeriale: [nil, ""])
      .index_by(&:codice_ministeriale)

    schedule = params[:schedule_dates] == "1" && source.iniziato_il.present? && @giro.iniziato_il.present?
    if schedule
      source_start = source.iniziato_il.to_date.beginning_of_week
      dest_start = @giro.iniziato_il.to_date.beginning_of_week
    end

    source_tappe = source.tappe.where(tappable_type: "Scuola")
      .joins("INNER JOIN scuole ON tappe.tappable_id = scuole.id")
      .select("tappe.*, scuole.codice_ministeriale AS source_codice")

    count = 0
    max_date = nil

    source_tappe.each do |source_tappa|
      codice = source_tappa.source_codice
      next if codice.blank?
      next if existing_codes.include?(codice)

      target_scuola = scuole_by_codice[codice]
      next unless target_scuola

      new_date = nil
      if schedule && source_tappa.data_tappa.present?
        offset = source_tappa.data_tappa - source_start
        new_date = dest_start + offset
        max_date = [max_date, new_date].compact.max
      end

      tappa = current_user.tappe.create!(
        tappable_type: "Scuola",
        tappable_id: target_scuola.id,
        account: Current.account,
        data_tappa: new_date
      )
      tappa.tappa_giri.create!(giro: @giro)
      existing_codes << codice
      count += 1
    end

    # Estendi finito_il se le date copiate lo superano
    if schedule && max_date && (@giro.finito_il.nil? || max_date > @giro.finito_il.to_date)
      @giro.update!(finito_il: max_date.end_of_week)
    end

    redirect_to giro_path(@giro), notice: "#{count} tappe copiate da #{source.titolo}."
  end

  # DELETE /giri/:giro_id/svuota_tappe
  def destroy_all
    tappe = @giro.tappe
    count = tappe.size
    tappe.each(&:destroy!)

    redirect_to giro_path(@giro), alert: "#{count} tappe rimosse."
  end

  private

  def set_giro
    @giro = current_user.giri.find(params[:giro_id])
  end

  def scuole_filtrate
    Current.scuole
      .non_scartate
      .where.not(id: Scuola.unscoped.select(:direzione_id).where.not(direzione_id: nil))
      .includes(:direzione)
      .order(:posizione)
  end

  def planner_tappe_per_area
    tappe = @giro.tappe
      .da_programmare
      .where(tappable_type: "Scuola")
      .includes(:giri)
      .preload(:tappable)
      .to_a

    scuole = tappe.map(&:tappable).compact.uniq
    ActiveRecord::Associations::Preloader.new(records: scuole, associations: :direzione).call

    tappe
      .group_by { |t| t.tappable.area.presence || "Senza area" }
      .sort_by { |area, _| area == "Senza area" ? "zzz" : area }
      .map { |area, area_tappe|
        direzioni = area_tappe
          .group_by { |t| t.tappable.direzione || t.tappable }
          .sort_by { |dir, _| dir.denominazione.to_s }
        [area, direzioni]
      }
  end

  # Costruisce hash annidato: { provincia => { area => { direzione => [plessi] } } }
  def build_gerarchia(scuole)
    result = {}

    scuole.each do |scuola|
      prov = scuola.provincia.presence || "Senza provincia"
      area = scuola.area.presence || "Senza area"
      dir_label = scuola.direzione&.denominazione || "Autonome"

      result[prov] ||= {}
      result[prov][area] ||= {}
      result[prov][area][dir_label] ||= []
      result[prov][area][dir_label] << scuola
    end

    result
  end
end
