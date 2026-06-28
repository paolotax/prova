class UpdateScuolaMieAdozioniJob < ApplicationJob
  queue_as :default

  def perform(account, scuola_id:)
    Current.account = account
    Rails.application.routes.default_url_options[:host] ||= ENV.fetch("APP_HOST", "localhost:3002")
    scuola = account.scuole.find(scuola_id)

    # Raccogli tutti gli ID scuola: direzione + plessi, oppure solo la scuola
    scuola_ids = if scuola.direzione_id.present?
      # Plesso singolo: ricalcola per tutta la direzione
      [scuola.direzione_id] + scuola.direzione.plessi.pluck(:id)
    elsif scuola.plessi.any?
      [scuola.id] + scuola.plessi.pluck(:id)
    else
      [scuola.id]
    end

    classe_scope = "classe_id IN (SELECT id FROM classi WHERE scuola_id IN (:scuola_ids))"
    sql_params = { account_id: account.id, scuola_ids: scuola_ids }

    # Reset
    Adozione.where(account: account)
      .where("classe_id IN (SELECT id FROM classi WHERE scuola_id IN (?))", scuola_ids)
      .update_all(mia: false, disdetta: false)

    # Set mia = true
    sql_mia = <<~SQL
      UPDATE adozioni SET mia = true
      WHERE adozioni.account_id = :account_id
      AND #{classe_scope}
      AND EXISTS (
        SELECT 1 FROM mandati m
        JOIN editori e ON e.id = m.editore_id
        JOIN classi c ON c.id = adozioni.classe_id
        JOIN scuole s ON s.id = c.scuola_id
        WHERE m.account_id = adozioni.account_id
          AND e.editore = adozioni.editore
          AND m.provincia = s.provincia
          AND m.grado = s.grado
          AND (m.area IS NULL OR m.area = s.area)
          AND NOT (m.area IS NOT NULL AND m.disdetta = true)
      )
      AND NOT EXISTS (
        SELECT 1 FROM mandati m2
        JOIN editori e2 ON e2.id = m2.editore_id
        JOIN classi c2 ON c2.id = adozioni.classe_id
        JOIN scuole s2 ON s2.id = c2.scuola_id
        WHERE m2.account_id = adozioni.account_id
          AND m2.disdetta = true
          AND m2.area IS NOT NULL
          AND m2.area = s2.area
          AND e2.editore = adozioni.editore
          AND m2.provincia = s2.provincia
          AND m2.grado = s2.grado
      )
    SQL

    execute(sql_mia, sql_params)

    # Set disdetta = true (solo wildcard disdette)
    sql_disdetta = <<~SQL
      UPDATE adozioni SET disdetta = true
      WHERE adozioni.account_id = :account_id
      AND adozioni.mia = true
      AND #{classe_scope}
      AND EXISTS (
        SELECT 1 FROM mandati m
        JOIN editori e ON e.id = m.editore_id
        JOIN classi c ON c.id = adozioni.classe_id
        JOIN scuole s ON s.id = c.scuola_id
        WHERE m.account_id = adozioni.account_id
          AND m.disdetta = true
          AND m.area IS NULL
          AND e.editore = adozioni.editore
          AND m.provincia = s.provincia
          AND m.grado = s.grado
      )
    SQL

    execute(sql_disdetta, sql_params)

    # Aggiorna counter solo per queste scuole
    update_counters(account, scuola_ids)

    # Broadcast replace della card intera (con totali ricalcolati)
    broadcast_card(account, scuola)
  end

  private

  def update_counters(account, scuola_ids)
    sql_params = { account_id: account.id, scuola_ids: scuola_ids }

    sql_mie = <<~SQL
      UPDATE scuole SET mie_adozioni_count = sub.cnt
      FROM (
        SELECT c.scuola_id, COUNT(*) as cnt
        FROM adozioni a
        JOIN classi c ON c.id = a.classe_id
        WHERE c.scuola_id IN (:scuola_ids)
          AND a.account_id = :account_id
          AND a.mia = true
          AND a.da_acquistare = true
          AND c.stato = 'attiva'
          AND a.anno_scolastico IS NOT DISTINCT FROM c.anno_scolastico
        GROUP BY c.scuola_id
      ) sub
      WHERE scuole.id = sub.scuola_id
    SQL

    execute(sql_mie, sql_params)

    # Reset per scuole senza adozioni mia
    sql_reset = <<~SQL
      UPDATE scuole SET mie_adozioni_count = 0
      WHERE scuole.id IN (:scuola_ids)
        AND scuole.id NOT IN (
          SELECT DISTINCT c.scuola_id FROM adozioni a
          JOIN classi c ON c.id = a.classe_id
          WHERE a.account_id = :account_id
            AND a.mia = true
            AND a.da_acquistare = true
            AND c.stato = 'attiva'
            AND a.anno_scolastico IS NOT DISTINCT FROM c.anno_scolastico
            AND c.scuola_id IN (:scuola_ids)
        )
    SQL

    execute(sql_reset, sql_params)
  end

  def broadcast_card(account, scuola)
    # Risali alla direzione se è un plesso
    root = if scuola.direzione_id.present?
      scuola.direzione
    else
      scuola
    end.reload

    if root.plessi.any?
      plessi = root.plessi.reload
      plessi_by_area = plessi.group_by { |p| p.area.presence }

      if plessi_by_area.keys.size > 1
        # Plessi divisi tra aree diverse — broadcast card separate per area
        broadcast_split_cards(account, root, plessi_by_area)
        return
      end

      gruppo = { direzione: root, plessi: plessi }
    else
      gruppo = { direzione: nil, plessi: [root] }
    end

    Turbo::StreamsChannel.broadcast_replace_to(
      [account, "aree", root.provincia],
      target: ActionView::RecordIdentifier.dom_id(root, :card),
      partial: "scuole/direzione_group",
      locals: { gruppo: gruppo, draggable: true }
    )
  end

  def broadcast_split_cards(account, root, plessi_by_area)
    base_id = ActionView::RecordIdentifier.dom_id(root, :card)

    plessi_by_area.each do |area, plessi|
      if area.nil?
        # Plessi senza area — id originale della card
        target_id = base_id
        card_id = nil
      else
        # Plessi in area specifica — id suffissato (match con JS clone)
        target_id = "#{base_id}_#{area.parameterize}"
        card_id = target_id
      end

      gruppo = { direzione: root, plessi: plessi }

      Turbo::StreamsChannel.broadcast_replace_to(
        [account, "aree", root.provincia],
        target: target_id,
        partial: "scuole/direzione_group",
        locals: { gruppo: gruppo, draggable: true, card_id: card_id }
      )
    end
  end

  def execute(sql, params)
    ActiveRecord::Base.connection.execute(
      ActiveRecord::Base.sanitize_sql([sql, params])
    )
  end
end
