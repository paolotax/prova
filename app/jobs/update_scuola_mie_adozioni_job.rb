class UpdateScuolaMieAdozioniJob < ApplicationJob
  # :bulk di default perché in promozione di massa ne viene accodato uno per scuola
  # (da promuovi_primaria!). Le chiamate interattive (assegnazioni/mandati) lo lanciano
  # esplicitamente con .set(queue: :default) per restare reattive.
  queue_as :bulk

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

    # Flag mia/disdetta + counter cache: logica set-based estratta in Adozione::Ricalcolo
    Adozione::Ricalcolo.new(account: account, scuola_ids: scuola_ids).call

    # Broadcast replace della card intera (con totali ricalcolati)
    broadcast_card(account, scuola)
  end

  private

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
end
