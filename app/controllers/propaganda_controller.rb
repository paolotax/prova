class PropagandaController < ApplicationController
  include FilterScoped

  FILTER_PARAMS = [province: [], aree: [], giro_ids: [], terms: []].freeze

  def index
    @scuole = @filter.scuole
    @giri = load_giri
    @tappe_map = build_tappe_map
  end

  private

  # Override FilterScoped convention: PropagandaController -> PropagandumFilter
  def filter_class
    ::Filters::PropagandaFilter
  end

  def filtering_class
    ::Filters::PropagandaFilter::Filtering
  end

  def load_giri
    if @filter.giro_ids.present?
      current_user.giri.where(id: @filter.giro_ids)
    else
      current_user.giri.where(finito_il: nil).or(current_user.giri.where(finito_il: Date.current..))
    end
  end

  def build_tappe_map
    return {} if @giri.empty?

    giro_ids = @giri.pluck(:id)

    tappe = Tappa.where(tappable_type: "Scuola", tappable_id: @scuole.select(:id))
      .joins(:tappa_giri).where(tappa_giri: { giro_id: giro_ids })
      .includes(:tappa_giri, bolle_visione: :bolla_visione_righe)

    # Preload entries separately (entryable_id is string, tappe.id is uuid — can't JOIN)
    tappa_ids = tappe.map(&:id).map(&:to_s)
    entries = Entry.where(entryable_type: "Tappa", entryable_id: tappa_ids)
      .includes(:closure, :goldness, :not_now)
      .index_by(&:entryable_id)
    tappe.each { |t| t.association(:entry).target = entries[t.id.to_s] }

    map = {}
    tappe.each do |tappa|
      tappa.tappa_giri.each do |tg|
        next unless giro_ids.include?(tg.giro_id)
        map[[tappa.tappable_id, tg.giro_id]] = tappa
      end
    end
    map
  end
end
