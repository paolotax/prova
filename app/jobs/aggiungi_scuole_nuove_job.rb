class AggiungiScuoleNuoveJob < ApplicationJob
  queue_as :bulk

  # Aggiunge all'anagrafe account le "nuove scuole" del controllo adozioni (codici in
  # miur_scuole+miur_adozioni senza predecessore ne' candidati), opzionalmente di una
  # sola provincia. Con `codici:` aggiunge solo quei codici (aggiunta singola dalla riga),
  # comunque validati come :nuova dalla Panoramica. Anagrafe da miur_scuole (direzioni
  # comprese), poi classi e adozioni via Adozione::Reconciler per provincia (idempotente).
  def perform(account, provincia: nil, codici: nil)
    Current.account = account
    anno = Miur.anno_corrente
    return if anno.blank?

    scuole = provincia ? account.scuole.where(provincia: provincia) : nil
    panoramica = ControlloAdozioni::Panoramica.new(account: account, scuole: scuole,
                                                   provincia: provincia)
    nuove = panoramica.cambi_codice.select { |m| m.tipo == :nuova }
    nuove = nuove.select { |m| codici.include?(m.codice) } if codici
    return if nuove.empty?

    province = inserisci_scuole(account, nuove.map(&:codice), anno)
    province.each { |prov| Adozione::Reconciler.new(account: account, provincia: prov, anno: anno).call }

    broadcast(account, province)
  end

  private

  # Insert idempotente delle scuole (e direzioni mancanti) via
  # Scuola::AnagrafeMiur. Ritorna le province coinvolte.
  def inserisci_scuole(account, codici, anno)
    nuove = Miur::Scuola.where(anno_scolastico: anno, codice_scuola: codici).to_a
    Scuola::AnagrafeMiur.new(account: account, miur_scuole: nuove, anno: anno).call
    nuove.map { |n| n.provincia&.upcase }.compact.uniq
  end

  # Refresh completo (morph) delle viste interessate: la pagina controllo_adozioni
  # (per provincia coinvolta e vista "tutte") e l'elenco scuole. Il refresh sullo
  # stream controllo_adozioni_riepilogo/<scope> è raccolto dalla pagina merge, che vi
  # si iscrive; niente più stream controllo_adozioni_dashboard (la dashboard separata
  # non esiste più dopo il merge).
  def broadcast(account, province)
    (province + ["_all"]).each do |scope|
      Turbo::StreamsChannel.broadcast_refresh_to(account, "controllo_adozioni_riepilogo", scope)
    end
    Turbo::StreamsChannel.broadcast_refresh_to(account, "scuole")
  end
end
