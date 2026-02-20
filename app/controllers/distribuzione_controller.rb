class DistribuzioneController < ApplicationController
  before_action :require_admin!

  def show
    @memberships = Current.account.memberships.includes(:user).where.not(role: :owner).order(:role, :created_at)
    scuole = Current.account.scuole.includes(:direzione, :plessi, :membership_scuole, classi: :adozioni)
                    .order(:comune, :denominazione)

    # Raggruppa per membership guardando TUTTE le scuole (non solo direzioni)
    # Una scuola è "assegnata" a un membership se ha un membership_scuola per quel membership
    @scuole_by_membership = {}
    @non_assegnate = []

    # Per la vista raggruppata: mostriamo le direzioni con i loro plessi,
    # e le scuole isolate singolarmente
    scuole_index = scuole.index_by(&:id)

    scuole.each do |scuola|
      # Salta i plessi — li mostriamo sotto la loro direzione
      next if scuola.direzione_id.present? && scuole_index[scuola.direzione_id]

      membership_ids = scuola_membership_ids(scuola, scuole_index)

      if membership_ids.empty?
        @non_assegnate << scuola
      else
        membership_ids.each do |mid|
          @scuole_by_membership[mid] ||= []
          @scuole_by_membership[mid] << scuola
        end
      end
    end
  end

  private

  def require_admin!
    unless Current.admin?
      redirect_to account_root_path, alert: "Accesso non autorizzato"
    end
  end

  # Membership IDs per una scuola: unione delle assegnazioni della scuola
  # e di tutti i suoi plessi (se è una direzione)
  def scuola_membership_ids(scuola, scuole_index)
    ids = scuola.membership_scuole.map(&:membership_id)

    if scuola.plessi.loaded?
      scuola.plessi.each do |plesso|
        ids.concat(plesso.membership_scuole.map(&:membership_id))
      end
    end

    ids.uniq
  end
end
