class PromuoviScuolePromuovibiliJob < ApplicationJob
  queue_as :bulk

  # Promuove (passaggio anno EE) tutte le scuole promuovibili dell'account allo snapshot
  # MIUR corrente. Fan-out: una ScuolaPromuoviClassiJob per scuola (promuove + broadcast
  # della riga in controllo_adozioni), così i fallimenti sono isolati e le righe si
  # aggiornano man mano.
  def perform(account)
    anno = NewScuola.maximum(:anno_scolastico)
    return if anno.blank?

    codici = account.scuole.where.not(codice_ministeriale: [nil, ""]).pluck(:codice_ministeriale)
    return if codici.empty?

    max_anno = account.scuole.joins(:classi).where(classi: { stato: "attiva" })
                      .group("scuole.codice_ministeriale").maximum("classi.anno_scolastico")
    ns = NewScuola.where(codice_scuola: codici, anno_scolastico: anno).pluck(:codice_scuola).to_set
    na = NewAdozione.where(codicescuola: codici, tipogradoscuola: "EE").distinct.pluck(:codicescuola).to_set

    account.scuole.where(codice_ministeriale: codici).find_each do |scuola|
      c = scuola.codice_ministeriale
      next unless ns.include?(c) && na.include?(c) && max_anno[c].to_s < anno

      ScuolaPromuoviClassiJob.perform_later(scuola, da: max_anno[c], a: anno)
    end
  end
end
