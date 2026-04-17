class Giri::Tappe::GenerazioneController < ApplicationController
  before_action :authenticate_user!
  before_action :set_giro

  def new
    base_scuole = @giro.scuole_disponibili_per_tappe
    @scuole = base_scuole.non_scartate
    @scuole_scartate = base_scuole.scartate_da_utente
    @gerarchia = build_gerarchia(@scuole)
  end

  def create
    count = @giro.genera_tappe_per(school_ids: params[:school_ids], user: current_user)

    @tappe_per_area = @giro.tappe.da_programmare.raggruppate_per_area
    @planner_total  = @tappe_per_area.sum { |_, dirs| dirs.sum { |_, t| t.size } }

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to giro_path(@giro), notice: "#{count} tappe generate." }
    end
  end

  private

  def set_giro
    @giro = current_user.giri.find(params[:giro_id])
  end

  def build_gerarchia(scuole)
    scuole.each_with_object({}) do |scuola, result|
      prov = scuola.provincia.presence || "Senza provincia"
      area = scuola.area.presence || "Senza area"
      dir_label = scuola.direzione&.denominazione || "Autonome"

      result[prov] ||= {}
      result[prov][area] ||= {}
      result[prov][area][dir_label] ||= []
      result[prov][area][dir_label] << scuola
    end
  end
end
