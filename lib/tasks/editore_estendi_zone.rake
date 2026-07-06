namespace :editore do
  # Estende l'anagrafe di un account editore a TUTTE le province presenti in
  # new_scuole, poi ricostruisce adozioni e counter. Idempotente e ri-eseguibile:
  # se una fase si interrompe (SSH caduto, job morto), rilanciare lo stesso task
  # riprende da dove era rimasto senza duplicare dati.
  #
  #   kamal app exec --reuse --roles=job "bin/rails 'editore:estendi_zone[ACCOUNT_ID]'"
  #   # oppure via ENV:
  #   kamal app exec --reuse --roles=job "bin/rails editore:estendi_zone ACCOUNT_ID=<uuid>"
  #   # dry-run (stampa solo il piano, non tocca nulla):
  #   kamal app exec --reuse --roles=job "bin/rails editore:estendi_zone ACCOUNT_ID=<uuid> DRY_RUN=1"
  #
  # Sequenza: crea zone mancanti -> attende conteggio (pronta) -> import scuole
  # per zona -> attende attiva -> svuota residui vecchio flusso -> reconcile
  # set-based (fan-out per provincia x anno) -> attende -> UpdateMieAdozioni
  # (sezioni_count mandati + libri) -> ANALYZE.
  desc "Estende zone+adozioni di un account editore a tutte le province di new_scuole (idempotente)"
  task :estendi_zone, [:account_id] => :environment do |_t, args|
    require "sidekiq/api"

    # Province sarde soppresse: presenti in new_scuole ma senza Zona di riferimento
    # (nessuna regione) -> impossibile creare la zona. Le stesse scuole entrano via
    # province canoniche (SASSARI, CAGLIARI, SUD SARDEGNA...) e il reconcile le
    # aggancia per codicescuola.
    sarde_fantasma = ["GALLURA NORD-EST SARDEGNA", "MEDIO CAMPIDANO", "OGLIASTRA", "SULCIS IGLESIENTE"]
    grado = "E"
    dry   = ENV["DRY_RUN"].present?

    account_id = args[:account_id].presence || ENV["ACCOUNT_ID"].presence
    account =
      if account_id
        Account.find(account_id)
      else
        cands = Account.all.select { |a| a.name.to_s.downcase.include?("bacherini") }
        abort "ACCOUNT_ID mancante e nessun account 'bacherini' trovato" if cands.empty?
        abort "Ambiguo: #{cands.map(&:name).inspect} — passa ACCOUNT_ID esplicito" if cands.size > 1
        cands.first
      end

    log = ->(msg) { puts "[#{Time.current.strftime('%H:%M:%S')}] #{msg}" }

    # Conta job (queue + in esecuzione + scheduled + retry) su bulk che
    # menzionano sia la classe sia l'id account (ActiveJob serializza il GlobalID).
    bulk_jobs = lambda do |klass|
      needle = account.id
      n = 0
      Sidekiq::Queue.new("bulk").each { |j| s = j.value.to_s; n += 1 if s.include?(klass) && s.include?(needle) }
      Sidekiq::Workers.new.each { |_p, _t, w| s = w.to_s; n += 1 if s.include?(klass) && s.include?(needle) }
      [Sidekiq::ScheduledSet.new, Sidekiq::RetrySet.new].each do |set|
        set.each { |j| s = j.value.to_s; n += 1 if s.include?(klass) && s.include?(needle) }
      end
      n
    end

    wait_until = lambda do |desc, timeout_min:, &done|
      deadline = timeout_min * 60
      waited = 0
      loop do
        return true if done.call
        if waited >= deadline
          log.call "TIMEOUT dopo #{timeout_min} min in fase: #{desc} — interrompo. Rilancia il task per riprendere."
          abort "Fase non completata: #{desc}"
        end
        sleep 15
        waited += 15
        log.call "…in attesa: #{desc} (#{waited / 60}m#{waited % 60}s)" if waited % 60 == 0
      end
    end

    log.call "Account: #{account.name} (#{account.id})"
    log.call "Zone attuali: #{account.zone.count} | Stati: #{account.zone.group(:stato).count}"

    # ── FASE 1: crea zone mancanti ─────────────────────────────────────────────
    esistenti = account.zone.distinct.pluck(:provincia)
    mancanti = Miur::Scuola.per_anno(Miur.anno_corrente).distinct.pluck(:provincia).compact - esistenti - sarde_fantasma
    senza_regione = []
    da_creare = mancanti.sort.filter_map do |prov|
      z = Zona.find_by(provincia: prov)
      z ? [prov, z.regione] : (senza_regione << prov; nil)
    end
    log.call "Province mancanti: #{mancanti.size} | creabili: #{da_creare.size} | senza regione (skip): #{senza_regione.inspect}"

    if dry
      log.call "DRY_RUN: mi fermo qui. Zone che verrebbero create (#{da_creare.size}): #{da_creare.map(&:first).inspect}"
      next
    end

    if da_creare.any?
      da_creare.each { |prov, reg| account.add_zone!(regione: reg, provincia: prov, grado: grado) }
      log.call "Create #{da_creare.size} zone (stato iniziale 'conteggio', CountScuolePerZonaJob auto-accodato)."
    else
      log.call "Nessuna zona da creare."
    end

    # Ri-accoda il conteggio per zone rimaste bloccate in 'conteggio' (job morto).
    account.zone.where(stato: "conteggio").find_each { |z| CountScuolePerZonaJob.perform_later(z) }
    wait_until.call("conteggio scuole", timeout_min: 15) { account.zone.where(stato: "conteggio").none? }
    log.call "Conteggio completato. Stati: #{account.zone.group(:stato).count}"

    # ── FASE 2: import scuole per zona ─────────────────────────────────────────
    # Lancia per pronta E per zone bloccate in importazione (import idempotente:
    # upsert_all/insert_all con unique_by). Non tocca le 'attiva'.
    da_importare = account.zone.where(stato: %w[pronta importazione]).to_a
    da_importare.each do |z|
      z.update!(stato: "importazione")
      ImportScuolePerZonaJob.perform_later(z)
    end
    log.call "Import accodati: #{da_importare.size}"
    wait_until.call("import scuole", timeout_min: 30) do
      account.zone.where(stato: %w[conteggio pronta importazione pulizia]).none?
    end
    log.call "Import completato. Zone attive: #{account.zone.where(stato: 'attiva').count} | Scuole: #{account.scuole.count}"

    # ── FASE 3: svuota residui del vecchio flusso dalla coda bulk ──────────────
    rimossi = 0
    Sidekiq::Queue.new("bulk").each do |j|
      s = j.value.to_s
      if s.include?(account.id) && (s.include?("UpdateScuolaMieAdozioniJob") || s.include?("ScuolaPromuoviClassiJob"))
        j.delete
        rimossi += 1
      end
    end
    log.call "Residui vecchio flusso rimossi da bulk: #{rimossi}"

    # ── FASE 4: reconcile set-based (fan-out per provincia x anno) ─────────────
    account.reconcile_adozioni_later
    log.call "Fan-out ReconcileAccountJob accodato."
    sleep 5 # lascia partire il fan-out prima di misurare
    wait_until.call("reconcile adozioni", timeout_min: 60) do
      bulk_jobs.call("ReconcileAccountJob").zero? && bulk_jobs.call("ReconcileAdozioniJob").zero?
    end
    log.call "Reconcile completato. Adozioni: #{account.adozioni.count} | Classi: #{Classe.where(account: account).count}"

    # ── FASE 5: UpdateMieAdozioni (sezioni_count mandati + linking libri) ──────
    prev = account.reload.adozioni_aggiornate_at
    UpdateMieAdozioniJob.perform_later(account)
    log.call "UpdateMieAdozioniJob accodato."
    sleep 5
    wait_until.call("update mie adozioni", timeout_min: 30) do
      a = account.reload
      a.adozioni_aggiornate_at.present? && a.adozioni_aggiornate_at != prev && !a.aggiornamento_adozioni_in_corso?
    end
    log.call "Mie aggiornate: #{account.adozioni.where(mia: true).count} | " \
             "mandati sezioni_count>0: #{account.mandati.where('sezioni_count > 0').count}/#{account.mandati.count}"

    # ── FASE 6: ANALYZE ───────────────────────────────────────────────────────
    %w[classi adozioni scuole libri mandati account_zone].each do |t|
      ActiveRecord::Base.connection.execute("ANALYZE #{t}")
    end
    log.call "ANALYZE fatto."

    log.call "── COMPLETATO ──"
    log.call "Province con adozioni: #{account.adozioni.joins(classe: :scuola).distinct.count('scuole.provincia')} | " \
             "Zone: #{account.zone.count} | Scuole: #{account.scuole.count} | Adozioni: #{account.adozioni.count}"
  end
end
