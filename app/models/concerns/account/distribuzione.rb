module Account::Distribuzione
  extend ActiveSupport::Concern

  # Restituisce la distribuzione scuole partizionata per membership
  # Returns: { non_assegnate:, non_assegnate_grouped:, scuole_by_membership: }
  def distribuzione_scuole
    units = build_distribuzione_units
    assignments = load_distribuzione_assignments
    partition_distribuzione(units, assignments)
  end

  private

  # Costruisce le unità distribuibili:
  # - Direzione con plessi → una unità per ogni grado dei plessi
  # - Scuola isolata → una unità singola
  def build_distribuzione_units
    scuole.where(direzione_id: nil)
      .includes(:plessi)
      .order(:provincia, :comune, :denominazione)
      .flat_map do |scuola|
        if scuola.plessi.any?
          scuola.plessi.group_by { |p| p.grado || "altro" }.map do |grado, plessi|
            { scuola: scuola, plessi: plessi, grado: grado, id: "dir:#{scuola.id}:#{grado}" }
          end
        else
          [{ scuola: scuola, plessi: [], grado: scuola.grado || "altro", id: scuola.id }]
        end
      end
  end

  # Mappa scuola_id => [membership_ids] con un solo pluck
  def load_distribuzione_assignments
    pairs = Accounts::MembershipScuola
      .where(scuola_id: scuole.select(:id))
      .pluck(:scuola_id, :membership_id)

    hash = Hash.new { |h, k| h[k] = [] }
    pairs.each { |sid, mid| hash[sid] << mid }
    hash
  end

  # Partiziona le unità in non_assegnate e per-membership
  def partition_distribuzione(units, assignments)
    non_assegnate = []
    non_assegnate_grouped = {}
    assegnate = Hash.new { |h, k| h[k] = [] }

    units.each do |unit|
      check_ids = unit[:plessi].any? ? unit[:plessi].map(&:id) : [unit[:scuola].id]
      mids = check_ids.flat_map { |id| assignments[id] }.uniq

      if mids.empty?
        non_assegnate << unit
        key = [unit[:scuola].provincia || "—", unit[:grado]]
        (non_assegnate_grouped[key] ||= []) << unit
      else
        mids.each { |mid| assegnate[mid] << unit }
      end
    end

    scuole_by_membership = {}
    assegnate.each do |mid, lista|
      grouped = {}
      lista.each do |unit|
        key = [unit[:scuola].provincia || "—", unit[:grado]]
        (grouped[key] ||= []) << unit
      end
      scuole_by_membership[mid] = { list: lista, grouped: grouped }
    end

    { non_assegnate: non_assegnate, non_assegnate_grouped: non_assegnate_grouped, scuole_by_membership: scuole_by_membership }
  end
end
