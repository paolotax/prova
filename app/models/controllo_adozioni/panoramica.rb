module ControlloAdozioni
  # Panoramica owner/admin di controllo_adozioni:
  #  - `gruppi`: tutte le scuole dell'account CON adozioni (correnti o in miur_adozioni),
  #    raggruppate per direzione didattica e ordinate come scuole index, con il confronto
  #    fra i conteggi correnti (account) e quelli dello snapshot MIUR (miur_adozioni).
  #  - `cambi_codice`: codici presenti in miur_scuole+miur_adozioni nella zona dell'account
  #    ma assenti da account.scuole (nuove o cambi codice), con eventuale predecessore.
  class Panoramica
    # grado scuola → tipogradoscuola in miur_adozioni (E=primaria, M=medie, N=superiori NT/NO)
    TG = { "E" => %w[EE], "M" => %w[MM], "N" => %w[NT NO] }.freeze

    Riga = Struct.new(:scuola, :correnti_classi, :correnti_adozioni, :new_classi, :new_adozioni,
                      :promuovibile, :promossa, :nel_miur, :anomalie_count, :anomalie_tipi, keyword_init: true) do
      def disallineata?  = correnti_classi != new_classi || correnti_adozioni != new_adozioni
      def promuovibile?  = promuovibile
      def promossa?      = promossa
      def mancante_miur? = !nel_miur
      def anomalie?      = anomalie_count.to_i.positive?
    end

    # tipo: :match (predecessore certo) | :suggerimento (candidati da scegliere) | :nuova
    Mancante = Struct.new(:codice, :denominazione, :comune, :provincia, :predecessore, :candidati,
                          :classi, :adozioni, keyword_init: true) do
      def tipo
        if predecessore        then :match
        elsif candidati.present? then :suggerimento
        else :nuova
        end
      end
    end

    ORDINE_TIPO = { match: 0, suggerimento: 1, nuova: 2 }.freeze

    def initialize(account:, scuole: nil, provincia: nil)
      @account = account
      @scuole_scope = scuole || account.scuole
      @provincia = provincia
    end

    # [{ direzione: Scuola|nil, scuole: [Scuola, ...] }] — `scuole` sono le righe da mostrare
    # (plessi con adozioni + la direzione se ne ha); `direzione` resta come header del gruppo.
    def gruppi
      @gruppi ||= build_gruppi
    end

    # live: true calcola i conteggi correnti dal vivo (per il broadcast post-promozione,
    # quando i counter cache non sono ancora stati aggiornati dai job async).
    def riga(scuola, live: false)
      cl, ad = new_counts.fetch(scuola.codice_ministeriale, [0, 0])
      a = anomalie_by_codice[scuola.codice_ministeriale]
      cor_cl, cor_ad = live ? correnti_live(scuola) : [scuola.classi_count, scuola.adozioni_count]
      Riga.new(scuola: scuola, correnti_classi: cor_cl, correnti_adozioni: cor_ad,
               new_classi: cl, new_adozioni: ad,
               promuovibile: promuovibili_codici.include?(scuola.codice_ministeriale),
               promossa: promossa?(scuola),
               nel_miur: new_counts.key?(scuola.codice_ministeriale),
               anomalie_count: a&.n_anomalie.to_i, anomalie_tipi: a&.tipi.to_s)
    end

    def cambi_codice
      @cambi_codice ||= build_cambi_codice
    end

    # [n_classi_attive, "A/B"] di una scuola candidata predecessore (bulk in build_cambi_codice).
    def classi_sezioni(scuola)
      cambi_codice
      (@classi_sezioni || {}).fetch(scuola.id, [0, nil])
    end

    def promuovibili_count = promuovibili_codici.size

    private

    attr_reader :account, :scuole_scope

    def anno = @anno ||= Miur.anno_corrente

    # Anno_scolastico max delle classi attive per codice scuola (bulk).
    def max_anno_attive
      @max_anno_attive ||= scuole_scope.joins(:classi).where(classi: { stato: "attiva" })
                                       .group("scuole.codice_ministeriale").maximum("classi.anno_scolastico")
    end

    # Gia' promossa: ha classi attive all'anno dello snapshot MIUR corrente.
    def promossa?(scuola)
      anno.present? && max_anno_attive[scuola.codice_ministeriale].to_s >= anno
    end

    # Conteggi da miur_adozioni per codicescuola: [classi_distinte, righe_daacquist]
    def new_counts
      @new_counts ||= conta_miur(scuole_scope.where.not(codice_ministeriale: [nil, ""]).pluck(:codice_ministeriale))
    end

    def conta_miur(codici)
      return {} if codici.empty?

      Miur::Adozione.where(codicescuola: codici, anno_scolastico: anno).group(:codicescuola).pluck(
        :codicescuola,
        Arel.sql("COUNT(DISTINCT COALESCE(annocorso,'') || '|' || COALESCE(sezioneanno,''))"),
        Arel.sql("COUNT(DISTINCT COALESCE(annocorso,'') || '|' || COALESCE(sezioneanno,'') || '|' || COALESCE(codiceisbn,'')) FILTER (WHERE daacquist ILIKE 'S%')")
      ).each_with_object({}) { |(cod, cl, ad), h| h[cod] = [cl.to_i, ad.to_i] }
    end

    # Conteggi correnti dal vivo, allineati alla definizione dei counter cache
    # (classi attive; adozioni da_acquistare su classi attive, anno coerente).
    def correnti_live(scuola)
      classi = scuola.classi.attive.count
      adoz = scuola.adozioni.joins(:classe)
                   .where(classi: { stato: "attiva" }, da_acquistare: true)
                   .where("adozioni.anno_scolastico IS NOT DISTINCT FROM classi.anno_scolastico")
                   .count
      [classi, adoz]
    end

    # Anomalie per codicescuola (riuso ControlloAnomalia.classifica), in bulk.
    def anomalie_by_codice
      @anomalie_by_codice ||= begin
        codici = scuole_scope.where.not(codice_ministeriale: [nil, ""]).pluck(:codice_ministeriale)
        if codici.empty?
          {}
        else
          ControlloAnomalia.classifica.where(codicescuola: codici).index_by(&:codicescuola)
        end
      end
    end

    def promuovibili_codici
      @promuovibili_codici ||= begin
        a = anno
        if a.blank?
          Set.new
        else
          codici = scuole_scope.where.not(codice_ministeriale: [nil, ""]).pluck(:codice_ministeriale)
          ns = Miur::Scuola.where(codice_scuola: codici, anno_scolastico: a).pluck(:codice_scuola).to_set
          na = Miur::Adozione.where(codicescuola: codici, tipogradoscuola: "EE", anno_scolastico: a).distinct.pluck(:codicescuola).to_set
          codici.select { |c| ns.include?(c) && na.include?(c) && max_anno_attive[c].to_s < a }.to_set
        end
      end
    end

    def con_adozioni?(scuola)
      scuola.adozioni_count.to_i.positive? || new_counts.key?(scuola.codice_ministeriale)
    end

    def build_gruppi
      scuole = scuole_scope
                      .left_joins(:direzione)
                      .includes(:direzione, :plessi)
                      .order(*per_direzione_order)
                      .to_a
      by_id = scuole.index_by(&:id)
      incluse = scuole.select { |s| con_adozioni?(s) }.to_set

      gruppi = {}
      ordine = []
      senza_direzione = []
      scuole.each do |scuola|
        if scuola.direzione_id.present? && by_id[scuola.direzione_id]
          key = scuola.direzione_id
          (gruppi[key] ||= (ordine << key; { direzione: by_id[key], plessi: [] }))[:plessi] << scuola
        elsif scuola.direzione_id.present?
          senza_direzione << scuola
        elsif scuola.plessi.any? { |p| by_id[p.id] }
          gruppi[scuola.id] ||= (ordine << scuola.id; { direzione: scuola, plessi: [] })
        else
          senza_direzione << scuola
        end
      end

      # Righe = plessi con adozioni (+ la direzione stessa se ha adozioni).
      # La direzione resta come header anche se non ha adozioni proprie.
      result = ordine.filter_map do |key|
        g = gruppi[key]
        dir = g[:direzione]
        righe = []
        righe << dir if dir && incluse.include?(dir)
        righe.concat(g[:plessi].select { |p| incluse.include?(p) })
        next if righe.empty?
        { direzione: dir, scuole: righe }
      end

      # Un unico gruppo "Scuole private" in coda per le scuole senza direzione.
      private_scuole = senza_direzione.select { |s| incluse.include?(s) }
      result << { direzione: nil, private: true, scuole: private_scuole } if private_scuole.any?
      result
    end

    def per_direzione_order
      [
        Arel.sql("COALESCE(direzioni_scuole.provincia, scuole.provincia)"),
        Arel.sql("COALESCE(direzioni_scuole.area, scuole.area) NULLS FIRST"),
        Arel.sql("COALESCE(direzioni_scuole.comune, scuole.comune)"),
        Arel.sql("COALESCE(direzioni_scuole.denominazione, scuole.denominazione)"),
        :tipo_scuola, :denominazione
      ]
    end

    # Codici miur_adozioni per tipogradoscuola (nazionale, distinct). Memoizzato per grado:
    # invariante rispetto alla provincia, quindi calcolato una volta sola per tg.
    def codici_con_adoz_per_tg(tg)
      (@codici_con_adoz_per_tg ||= {})[tg] ||=
        Miur::Adozione.where(tipogradoscuola: tg, anno_scolastico: anno).distinct.pluck(:codicescuola).to_set
    end

    def paritaria?(tipo) = tipo.to_s.upcase.include?("NON STATALE")

    # Normalizzazione e similarità denominazione: sorgente unica in Classificazione,
    # gemella della NORM in SQL (vedi invariante documentato lì e testato).
    def denom_norm(s) = Classificazione.denom_norm(s)

    def denom_simili?(a, b) = Classificazione.denom_simili?(a, b)

    # Codici in miur_scuole+miur_adozioni (zona account) assenti da account.scuole.
    def build_cambi_codice
      righe = []
      # Le direzioni non possono essere predecessore di un cambio codice (una scuola non
      # diventa direzione): le escludiamo dai candidati.
      direzione_ids = account.scuole.where.not(direzione_id: nil).distinct.pluck(:direzione_id).to_set
      zone = account.zone.order(:provincia, :grado)
      zone = zone.where(provincia: @provincia) if @provincia
      zone.each do |zona|
        tipi = TipoScuola.where(grado: zona.grado).pluck(:tipo)
        tg = TG[zona.grado] || []
        next if tg.empty?

        in_account = account.scuole.where(provincia: zona.provincia, grado: zona.grado)
        account_codici = in_account.pluck(:codice_ministeriale).to_set
        # Dipende solo dal grado (tg), non dalla provincia: memoizza per non ripetere la
        # stessa distinct nazionale una volta per zona (per un editore = decine di zone EE).
        codici_con_adoz = codici_con_adoz_per_tg(tg)

        # Scuole account "orfane" (codice non piu' in miur_adozioni) → possibili predecessori.
        # Escludi le direzioni.
        orfane_per_comune = in_account
          .reject { |s| codici_con_adoz.include?(s.codice_ministeriale) || direzione_ids.include?(s.id) }
          .group_by(&:comune)

        Miur::Scuola.where(provincia: zona.provincia, tipo_scuola: tipi, anno_scolastico: anno)
                 .pluck(:codice_scuola, :denominazione, :comune, :tipo_scuola).each do |codice, denom, comune, tipo|
          next if account_codici.include?(codice) || !codici_con_adoz.include?(codice)

          # Candidati predecessore: orfane dello stesso comune E stessa natura
          # (statale ↔ statale, paritaria ↔ paritaria).
          paritaria = paritaria?(tipo)
          candidati = (orfane_per_comune[comune] || []).select { |s| paritaria?(s.tipo_scuola) == paritaria }

          # Auto-suggerimento solo se una sola candidata ha denominazione simile.
          simili = candidati.select { |s| denom_simili?(s.denominazione, denom) }
          predecessore = simili.size == 1 ? simili.first : nil

          righe << Mancante.new(codice: codice, denominazione: denom, comune: comune,
                                provincia: zona.provincia, predecessore: predecessore,
                                candidati: candidati)
        end
      end

      conteggi = conta_miur(righe.map(&:codice))
      righe.each { |m| m.classi, m.adozioni = conteggi.fetch(m.codice, [0, 0]) }

      # Classi attive e sezioni dei candidati predecessore, per riconoscerli nella select.
      candidati_ids = righe.flat_map { |m| m.candidati.map(&:id) }.uniq
      @classi_sezioni = Classe.attive.where(scuola_id: candidati_ids).group(:scuola_id).pluck(
        :scuola_id, Arel.sql("COUNT(*)"),
        Arel.sql("STRING_AGG(DISTINCT COALESCE(sezione, ''), '/' ORDER BY COALESCE(sezione, ''))")
      ).each_with_object({}) { |(id, n, sez), h| h[id] = [n.to_i, sez.presence] }

      righe.sort_by { |m| [ORDINE_TIPO.fetch(m.tipo), m.provincia.to_s, m.comune.to_s, m.denominazione.to_s] }
    end
  end
end
