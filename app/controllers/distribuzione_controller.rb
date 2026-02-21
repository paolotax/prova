class DistribuzioneController < ApplicationController
  before_action :require_admin!

  def show
    @memberships = Current.account.memberships.includes(:user).where.not(role: :owner).order(:role, :created_at)

    all_scuole = Current.account.scuole.where(direzione_id: nil)
      .includes(:plessi)
      .order(:provincia, :comune, :denominazione)

    # Mappa scuola_id => [membership_ids] con un solo pluck
    assignments = MembershipScuola
      .where(scuola_id: Current.account.scuole.select(:id))
      .pluck(:scuola_id, :membership_id)

    scuola_memberships = Hash.new { |h, k| h[k] = [] }
    assignments.each { |sid, mid| scuola_memberships[sid] << mid }

    # Costruisce le unità distribuibili:
    # - Direzione con plessi: una unità per ogni grado dei plessi
    # - Scuola isolata: una unità singola
    units = []
    all_scuole.each do |scuola|
      if scuola.plessi.any?
        scuola.plessi.group_by { |p| p.grado || "altro" }.each do |grado, plessi|
          units << {
            scuola: scuola, plessi: plessi, grado: grado,
            id: "dir:#{scuola.id}:#{grado}"
          }
        end
      else
        units << {
          scuola: scuola, plessi: [], grado: scuola.grado || "altro",
          id: scuola.id
        }
      end
    end

    @non_assegnate = []
    @non_assegnate_grouped = {}
    assegnate = Hash.new { |h, k| h[k] = [] }

    units.each do |unit|
      # Per le unit con plessi, controlla solo i plessi (la direzione è condivisa).
      # Per le isolate, controlla la scuola stessa.
      check_ids = unit[:plessi].any? ? unit[:plessi].map(&:id) : [unit[:scuola].id]
      mids = check_ids.flat_map { |id| scuola_memberships[id] }.uniq

      if mids.empty?
        @non_assegnate << unit
        key = [unit[:scuola].provincia || "—", unit[:grado]]
        (@non_assegnate_grouped[key] ||= []) << unit
      else
        mids.each { |mid| assegnate[mid] << unit }
      end
    end

    @scuole_by_membership = {}
    assegnate.each do |mid, lista|
      grouped = {}
      lista.each do |unit|
        key = [unit[:scuola].provincia || "—", unit[:grado]]
        (grouped[key] ||= []) << unit
      end
      @scuole_by_membership[mid] = { list: lista, grouped: grouped }
    end
  end

  private

  def require_admin!
    unless Current.admin?
      redirect_to account_root_path, alert: "Accesso non autorizzato"
    end
  end
end
