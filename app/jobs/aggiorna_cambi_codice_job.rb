class AggiornaCambiCodiceJob < ApplicationJob
  queue_as :bulk

  # Applica in blocco tutti i cambi codice della panoramica che hanno un predecessore
  # suggerito, opzionalmente limitati a una provincia (drill-down admin): aggiorna il
  # codice_ministeriale della scuola predecessore al nuovo codice MIUR e ne avvia il
  # passaggio anno. Fan-out: una ScuolaPromuoviClassiJob per scuola, così i fallimenti
  # sono isolati e le righe si aggiornano man mano.
  def perform(account, provincia: nil)
    anno = NewScuola.maximum(:anno_scolastico)
    return if anno.blank?

    scuole = provincia ? account.scuole.where(provincia: provincia) : nil
    panoramica = ControlloAdozioni::Panoramica.new(account: account, scuole: scuole,
                                                   provincia: provincia)
    panoramica.cambi_codice.each do |m|
      pred = m.predecessore
      next unless pred
      next if m.codice == pred.codice_ministeriale

      vecchio = pred.codice_ministeriale
      da = pred.classi.attive.maximum(:anno_scolastico) || precedente(anno)

      pred.update!(codice_ministeriale: m.codice,
                   note: [pred.note.presence, "ex codice #{vecchio}"].compact.join("\n"))

      ScuolaPromuoviClassiJob.perform_later(pred, da: da, a: anno)
    end
  end

  private

  # "202627" -> "202526"
  def precedente(anno)
    return nil if anno.blank? || anno.length != 6
    y1 = anno[0..3].to_i - 1
    "#{y1}#{(y1 + 1).to_s[-2..]}"
  end
end
