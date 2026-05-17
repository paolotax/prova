class BolleVisione::RientriController < BolleVisione::BaseController
  def create
    righe = @bolla_visione.bolla_visione_righe.aperte
    righe = filtra_per_gruppo(righe) if params[:gruppo].present?

    count = BollaVisioneRiga.transaction do
      righe.update_all(
        esito: BollaVisioneRiga.esiti[:rientrato],
        processato_at: Time.current
      )
    end

    redirect_to bolla_visione_path(@bolla_visione),
                notice: helpers.pluralize(count, "riga rientrata", plural: "righe rientrate")
  end

  def destroy
    righe = @bolla_visione.bolla_visione_righe.where(esito: BollaVisioneRiga.esiti[:rientrato])
    righe = filtra_per_gruppo(righe) if params[:gruppo].present?

    count = BollaVisioneRiga.transaction do
      righe.update_all(esito: nil, processato_at: nil)
    end

    redirect_to bolla_visione_path(@bolla_visione),
                notice: helpers.pluralize(count, "riga riaperta", plural: "righe riaperte")
  end

  private

  def filtra_per_gruppo(righe)
    libri_ids = CollanaLibro
      .where(collana_id: @bolla_visione.collana_id, gruppo: params[:gruppo])
      .pluck(:libro_id)
    righe.where(libro_id: espandi_con_fascicoli(libri_ids))
  end

  # Espande la lista includendo i fascicoli (anche transitivi) delle confezioni passate,
  # cosi' anche le righe esplose vengono raggiunte dal filtro per gruppo.
  def espandi_con_fascicoli(libri_ids)
    result = libri_ids.dup
    frontier = libri_ids
    until frontier.empty?
      children = ConfezioneRiga.where(confezione_id: frontier).pluck(:fascicolo_id).uniq - result
      result.concat(children)
      frontier = children
    end
    result
  end
end
