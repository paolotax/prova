module Accounts::Membership::ScuoleAssegnabili
  extend ActiveSupport::Concern

  # Assegna scuole a questo membership (opzionalmente spostandole da source)
  def assegna_scuole!(scuole, da: nil)
    da.rimuovi_scuole!(scuole) if da

    # Per i plessi, rimuovi assegnazioni ad altri membership (esclusiva)
    plessi = scuole.reject { |s| s.plessi.any? }
    if plessi.any?
      Accounts::MembershipScuola
        .where(scuola: plessi)
        .where.not(membership_id: id)
        .destroy_all
    end

    scuole.each { |s| membership_scuole.find_or_create_by!(scuola: s) }
    self.class.sync_direzioni_for(scuole, account: account)
  end

  # Rimuovi scuole da questo membership
  def rimuovi_scuole!(scuole)
    membership_scuole.where(scuola: scuole).destroy_all
    self.class.sync_direzioni_for(scuole, account: account)
  end

  class_methods do
    # Sincronizza le direzioni per tutti i membership coinvolti
    # Usabile anche senza un membership specifico (es. rimozione globale)
    def sync_direzioni_for(scuole, account:)
      scuola_ids = scuole.map(&:id)

      # Direzioni delle scuole coinvolte (plessi → loro direzione)
      dir_ids_from_plessi = account.scuole
        .where(id: scuola_ids)
        .where.not(direzione_id: nil)
        .distinct.pluck(:direzione_id)

      # Direzioni che sono nella lista (hanno plessi che le referenziano)
      dir_ids_in_list = account.scuole
        .where.not(direzione_id: nil)
        .where(direzione_id: scuola_ids)
        .distinct.pluck(:direzione_id) & scuola_ids

      dir_ids = (dir_ids_from_plessi + dir_ids_in_list).uniq

      dir_ids.each do |dir_id|
        plesso_ids = account.scuole.where(direzione_id: dir_id).pluck(:id)
        mids_con_plessi = Accounts::MembershipScuola.where(scuola_id: plesso_ids).distinct.pluck(:membership_id)

        # Aggiungi direzione a chi ha plessi
        mids_con_plessi.each do |mid|
          Accounts::MembershipScuola.find_or_create_by!(membership_id: mid, scuola_id: dir_id)
        end

        # Rimuovi direzione da chi non ha più plessi
        Accounts::MembershipScuola.where(scuola_id: dir_id)
          .where.not(membership_id: mids_con_plessi)
          .destroy_all
      end
    end
  end
end
