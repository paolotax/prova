class Distribuzione::AssegnazioniController < ApplicationController
  before_action :require_admin!

  def create
    scuole = resolve_scuole(params[:scuola_id])

    if params[:rimuovi].present?
      # Drop su "Non assegnate": rimuovi solo le scuole effettivamente assegnate alla sorgente
      if params[:source_membership_id].present?
        source = Current.account.memberships.find(params[:source_membership_id])
        source_ids = MembershipScuola.where(membership: source, scuola_id: scuole.map(&:id)).pluck(:scuola_id)
        scuole = scuole.select { |s| source_ids.include?(s.id) }
        MembershipScuola.where(scuola: scuole, membership: source).destroy_all
      else
        MembershipScuola.where(scuola: scuole).destroy_all
      end
    elsif params[:membership_id].present?
      membership = Current.account.memberships.find(params[:membership_id])

      if params[:source_membership_id].present?
        # Spostamento tra agenti: sposta solo le scuole assegnate alla sorgente
        source = Current.account.memberships.find(params[:source_membership_id])
        source_ids = MembershipScuola.where(membership: source, scuola_id: scuole.map(&:id)).pluck(:scuola_id)
        scuole = scuole.select { |s| source_ids.include?(s.id) }
        MembershipScuola.where(scuola: scuole, membership: source).destroy_all
      end

      # Assegna al target
      scuole.each { |s| membership.membership_scuole.find_or_create_by!(scuola: s) }
    end

    # Riallinea le direzioni: ogni agente che ha plessi deve avere la direzione,
    # chi non ha più plessi perde la direzione
    sync_direzioni(scuole)

    respond_to do |format|
      format.turbo_stream { redirect_to distribuzione_path, status: :see_other }
      format.html { redirect_to distribuzione_path }
    end
  end

  private

  def require_admin!
    unless Current.admin?
      redirect_to account_root_path, alert: "Accesso non autorizzato"
    end
  end

  # Sincronizza le MembershipScuola delle direzioni:
  # - agenti con plessi → devono avere la direzione
  # - agenti senza plessi → perdono la direzione
  def sync_direzioni(scuole)
    scuola_ids = scuole.map(&:id)

    # Trova quali delle scuole coinvolte sono direzioni
    dir_ids = Current.account.scuole
      .where.not(direzione_id: nil)
      .where(direzione_id: scuola_ids)
      .distinct.pluck(:direzione_id) & scuola_ids

    dir_ids.each do |dir_id|
      plesso_ids = Current.account.scuole.where(direzione_id: dir_id).pluck(:id)
      mids_con_plessi = MembershipScuola.where(scuola_id: plesso_ids).distinct.pluck(:membership_id)

      # Aggiungi direzione a chi ha plessi
      mids_con_plessi.each do |mid|
        MembershipScuola.find_or_create_by!(membership_id: mid, scuola_id: dir_id)
      end

      # Rimuovi direzione da chi non ha più plessi
      MembershipScuola.where(scuola_id: dir_id)
        .where.not(membership_id: mids_con_plessi)
        .destroy_all
    end
  end

  def resolve_scuole(scuola_id)
    if scuola_id.start_with?("prov:")
      provincia = scuola_id.delete_prefix("prov:")
      Current.account.scuole.where(provincia: provincia).to_a

    elsif scuola_id.start_with?("dir:")
      _, dir_id, grado = scuola_id.split(":", 3)
      direzione = Current.account.scuole.find(dir_id)
      plessi = direzione.plessi.where(grado: grado)
      [direzione] + plessi.to_a

    elsif scuola_id.start_with?("group:")
      _, provincia, grado = scuola_id.split(":", 3)
      plessi = Current.account.scuole.where(provincia: provincia, grado: grado)
      direzione_ids = plessi.where.not(direzione_id: nil).distinct.pluck(:direzione_id)
      direzioni = Current.account.scuole.where(id: direzione_ids)
      isolate = plessi.where(direzione_id: nil)
      (isolate.to_a + plessi.where.not(direzione_id: nil).to_a + direzioni.to_a).uniq

    else
      [Current.account.scuole.find(scuola_id)]
    end
  end
end
