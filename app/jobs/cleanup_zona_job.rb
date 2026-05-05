class CleanupZonaJob < ApplicationJob
  queue_as :bulk
  discard_on ActiveJob::DeserializationError

  include BroadcastsPulsanteAggiornaAdozioni

  def perform(account_zona)
    account = account_zona.account
    provincia = account_zona.provincia
    grado = account_zona.grado

    target_scope = account.scuole.where(provincia: provincia, grado: grado)
    target_ids = target_scope.pluck(:id)

    # Direzioni dei plessi in target che non sono esse stesse in target
    # (cross-provincia / cross-grado): da pulire se restano senza plessi
    direzioni_esterne = target_scope
      .where.not(direzione_id: nil)
      .distinct
      .pluck(:direzione_id) - target_ids

    if target_ids.empty?
      account_zona.destroy!
      broadcast_all(account)
      return
    end

    protette_ids = scuole_protette_ids(target_ids)
    non_protette_ids = target_ids - protette_ids.to_a

    bulk_delete_non_protette(non_protette_ids) if non_protette_ids.any?

    cleanup_direzioni_orfane(account, direzioni_esterne) if direzioni_esterne.any?

    if protette_ids.any?
      remaining = account.scuole.where(provincia: provincia, grado: grado).count
      account_zona.update!(stato: "attiva", scuole_count: remaining)
      Rails.logger.info "[CleanupZona] #{protette_ids.size} scuole protette restano (provincia=#{provincia} grado=#{grado})"
    else
      Accounts::Mandato
        .where(account_id: account.id, provincia: provincia, grado: grado)
        .delete_all
      account_zona.destroy!
    end

    broadcast_all(account)

    RebuildAccountAdozioniJob.perform_later(account)
  end

  private

  # Cancella le direzioni che, dopo aver eliminato i plessi della zona,
  # restano senza plessi. Solo se non protette.
  def cleanup_direzioni_orfane(account, direzione_ids)
    orfane_ids = account.scuole
      .where(id: direzione_ids)
      .left_joins(:plessi)
      .where(plessi_scuole: { id: nil })
      .pluck(:id)

    return if orfane_ids.empty?

    protette = scuole_protette_ids(orfane_ids)
    da_cancellare = orfane_ids - protette.to_a

    bulk_delete_non_protette(da_cancellare) if da_cancellare.any?
  end

  # Replica la semantica effettiva di ProtectedFromDestroy:
  # gli appunti diretti su Scuola/Persona NON proteggono (Appuntabile li
  # cancella in cascata prima del check). Una scuola è protetta se ha
  # documenti/tappe diretti, o classi con appunti/documenti/consegne_saggio,
  # o è direzione di un plesso (in target) protetto.
  def scuole_protette_ids(scuola_ids)
    return Set.new if scuola_ids.empty?

    classe_ids = Classe.where(scuola_id: scuola_ids).pluck(:id)
    protette = Set.new

    protette.merge(Documento.where(clientable_type: "Scuola", clientable_id: scuola_ids).pluck(:clientable_id))
    protette.merge(Tappa.where(tappable_type: "Scuola", tappable_id: scuola_ids).pluck(:tappable_id))

    if classe_ids.any?
      classi_protette = Set.new
      classi_protette.merge(Appunto.where(appuntabile_type: "Classe", appuntabile_id: classe_ids).pluck(:appuntabile_id))
      classi_protette.merge(Documento.where(clientable_type: "Classe", clientable_id: classe_ids).pluck(:clientable_id))
      classi_protette.merge(
        ConsegnaSaggio.joins(:adozione).where(adozioni: { classe_id: classe_ids }).pluck("adozioni.classe_id")
      )

      if classi_protette.any?
        protette.merge(Classe.where(id: classi_protette.to_a).pluck(:scuola_id))
      end
    end

    direzioni_protette = Scuola
      .where(direzione_id: scuola_ids)
      .where(id: protette.to_a)
      .pluck(:direzione_id)
      .uniq
    protette.merge(direzioni_protette)

    protette
  end

  def bulk_delete_non_protette(scuola_ids)
    return if scuola_ids.empty?

    ActiveRecord::Base.transaction do
      classe_ids = Classe.where(scuola_id: scuola_ids).pluck(:id)

      if classe_ids.any?
        adozione_ids = Adozione.where(classe_id: classe_ids).pluck(:id)

        if adozione_ids.any?
          ConsegnaSaggio.where(adozione_id: adozione_ids).delete_all
          Adozione.where(id: adozione_ids).delete_all
        end

        PersonaClasse.where(classe_id: classe_ids).delete_all
        Saggio.where(destinatario_type: "Classe", destinatario_id: classe_ids)
          .update_all(destinatario_type: nil, destinatario_id: nil)
        Appunto.where(appuntabile_type: "Classe", appuntabile_id: classe_ids).delete_all
        Classe.where(id: classe_ids).delete_all
      end

      persona_ids = Persona.where(scuola_id: scuola_ids).pluck(:id)
      if persona_ids.any?
        PersonaClasse.where(persona_id: persona_ids).delete_all
        Saggio.where(destinatario_type: "Persona", destinatario_id: persona_ids)
          .update_all(destinatario_type: nil, destinatario_id: nil)
        Appunto.where(appuntabile_type: "Persona", appuntabile_id: persona_ids).delete_all
        Persona.where(id: persona_ids).delete_all
      end

      Saggio.where(scuola_id: scuola_ids).delete_all
      Sconto.where(scontabile_type: "Scuola", scontabile_id: scuola_ids).delete_all
      Accounts::MembershipScuola.where(scuola_id: scuola_ids).delete_all
      Appunto.where(appuntabile_type: "Scuola", appuntabile_id: scuola_ids).delete_all

      Scuola.where(direzione_id: scuola_ids).update_all(direzione_id: nil)
      Scuola.where(id: scuola_ids).delete_all
    end
  end

  def broadcast_all(account)
    broadcast_zone_panel(account)
    broadcast_scuole_refresh(account)
    broadcast_pulsante_stato(account)
  end

  def broadcast_zone_panel(account)
    account_zone = account.zone.order(:regione, :provincia, :grado)

    Turbo::StreamsChannel.broadcast_replace_to(
      [account, "configurazione"],
      target: "zone-panel",
      partial: "accounts/zone/zone_list",
      locals: { account_zone: account_zone }
    )
  end

  def broadcast_scuole_refresh(account)
    account.memberships.find_each do |membership|
      Turbo::StreamsChannel.broadcast_refresh_later_to(membership, "scuole")
    end
  end
end
