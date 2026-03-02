class Giri::TappeController < ApplicationController
  before_action :authenticate_user!
  before_action :set_giro

  # GET /giri/:giro_id/genera_tappe
  def new
    all_scuole = scuole_filtrate
    existing_ids = @giro.tappe.where(tappable_type: "Scuola").pluck(:tappable_id).map(&:to_s).to_set
    @scuole = all_scuole.reject { |s| existing_ids.include?(s.id.to_s) }
    @gerarchia = build_gerarchia(@scuole)
  end

  # POST /giri/:giro_id/genera_tappe
  def create
    selected_ids = Array(params[:school_ids]).map(&:to_s)
    all_ids = Array(params[:all_school_ids]).map(&:to_s)

    # Aggiorna excluded_ids con le scuole deselezionate
    deselected = all_ids - selected_ids
    new_excluded = ((@giro.excluded_ids || []) + deselected).uniq
    @giro.update!(excluded_ids: new_excluded)

    # Crea tappe solo per le selezionate
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

    redirect_to giro_path(@giro), notice: "#{count} tappe generate."
  end

  # POST /giri/:giro_id/copia_tappe
  def copy
    source = current_user.giri.find(params[:source_giro_id])
    existing_ids = @giro.tappe.where(tappable_type: "Scuola").pluck(:tappable_id)

    source_tappe = source.tappe
      .where(tappable_type: "Scuola")
      .where.not(tappable_id: existing_ids)

    count = 0
    source_tappe.find_each do |source_tappa|
      tappa = current_user.tappe.create!(
        tappable_type: "Scuola",
        tappable_id: source_tappa.tappable_id,
        account: Current.account,
        data_tappa: nil
      )
      tappa.tappa_giri.create!(giro: @giro)
      count += 1
    end

    redirect_to giro_path(@giro), notice: "#{count} tappe copiate da #{source.titolo}."
  end

  private

  def set_giro
    @giro = current_user.giri.find(params[:giro_id])
  end

  def scuole_filtrate
    scuole = Current.scuole
    excluded = @giro.excluded_ids || []
    scuole = scuole.where.not(id: excluded) if excluded.any?
    # Solo plessi (scuole con direzione) e scuole autonome, mai le direzioni stesse
    scuole.where.not(id: Scuola.unscoped.select(:direzione_id).where.not(direzione_id: nil))
          .includes(:direzione)
          .order(:posizione)
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
