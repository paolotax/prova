module ControlloAdozioni
  # Dati della show scuola del controllo adozioni: anomalie raggruppate,
  # libri MIUR per classe, e il confronto per anno con la scuola in anagrafe
  # account (se presente). Nessuna persistenza.
  class Scheda
    RigaAnno = Struct.new(:anno, :classi_attive, :classi_archiviate, :adozioni, keyword_init: true)

    def initialize(account:, codicescuola:)
      @account = account
      @codicescuola = codicescuola
    end

    attr_reader :account, :codicescuola

    def anomalie = @anomalie ||= ControlloAnomalia.per_scuola(codicescuola)
    def per_tipo = @per_tipo ||= anomalie.group(:tipo).count

    def per_classe
      @per_classe ||= anomalie.where.not(annocorso: nil)
                              .group_by { |a| [a.annocorso, a.sezioneanno, a.combinazione] }
    end

    def scuola_mancante? = anomalie.per_tipo("scuola_mancante").exists?

    # Anno campagna corrente MIUR (max anagrafe scuole). nil se miur_scuole vuota.
    def anno_corrente = @anno_corrente ||= Miur.anno_corrente

    # Gia' promossa: classi attive della scuola account all'anno corrente MIUR.
    def promossa?
      scuola.present? && anno_corrente.present? &&
        scuola.classi.attive.where(anno_scolastico: anno_corrente).exists?
    end

    # Attiva ma con codice sparito dall'anagrafe MIUR dell'anno, non ancora promossa
    # (una scuola promossa ciecamente col codice sparito e' gia' gestita: niente
    # allarme). Stessa definizione in scuole/_fuori_anagrafe_banner.html.erb e
    # Classificazione#fuori_anagrafe — tenere allineate.
    def fuori_anagrafe?
      scuola&.stato == "attiva" && !scuola.gestione_manuale? && anno_corrente.present? &&
        !promossa? &&
        !Miur::Scuola.where(codice_scuola: codicescuola, anno_scolastico: anno_corrente).exists?
    end

    # La promozione cieca è l'unica strada quando manca il roster miur_adozioni EE
    # dell'anno: fuori anagrafe, gestione manuale, ma anche codice APPENA aggiornato
    # con adozioni non ancora pubblicate dal MIUR (caso Marco Polo). Col roster
    # presente si usa il passaggio anno normale.
    def promozione_cieca_possibile?
      scuola.present? && !promossa? && anno_corrente.present? &&
        scuola.classi.attive.exists? &&
        !Miur::Adozione.where(codicescuola: codicescuola, anno_scolastico: anno_corrente,
                              tipogradoscuola: "EE").exists?
    end

    # Candidati successore (delegati a Panoramica, stessa regola della riga).
    def successori
      @successori ||= fuori_anagrafe? ? Panoramica.new(account: account).successori(scuola) : []
    end

    # Anni anteprima per cui esiste l'elenco adozioni MIUR (per segnalare i vuoti).
    def anni_con_elenco
      @anni_con_elenco ||= Miur::Adozione.where(codicescuola: codicescuola, anno_scolastico: anni_anteprima)
                                         .distinct.pluck(:anno_scolastico).to_set
    end

    def denominazione
      @denominazione ||= anomalie.where.not(denominazione: nil).first&.denominazione ||
                         scuola&.denominazione
    end

    # La scuola in anagrafe account con questo codice (nil se non ancora acquisita).
    def scuola
      return @scuola if defined?(@scuola)

      @scuola = account.scuole.find_by(codice_ministeriale: codicescuola)
    end

    # Confronto per anno scolastico: classi attive/archiviate e adozioni della
    # scuola account, ordinato dall'anno piu' recente.
    def confronto_anni
      return [] unless scuola

      @confronto_anni ||= begin
        classi = scuola.classi.group(:anno_scolastico, :stato).count
        adozioni = scuola.adozioni.group(:anno_scolastico).count
        anni = (classi.keys.map(&:first) + adozioni.keys).compact.uniq.sort.reverse
        anni.map do |anno|
          RigaAnno.new(anno: anno,
                       classi_attive: classi.fetch([anno, "attiva"], 0),
                       classi_archiviate: classi.fetch([anno, "archiviata"], 0),
                       adozioni: adozioni.fetch(anno, 0))
        end
      end
    end

    # Anni per i link anteprima: corrente e precedente (design Sezione 4).
    def anni_anteprima
      corrente = AnnoScolastico.corrente or return []
      [corrente.to_s, corrente.precedente.to_s]
    end

    # Libri MIUR da acquistare (EE) raggruppati per classe, come @per_classe.
    # Spostato 1:1 da ControlloAdozioniController#libri_per_classe.
    def libri_per_classe
      @libri_per_classe ||= Miur::Adozione
        .per_anno(Miur.anno_corrente)
        .where(codicescuola: codicescuola, tipogradoscuola: "EE")
        .where("coalesce(daacquist, '') ILIKE 'S%'")
        .order(:annocorso, :sezioneanno, :combinazione, :disciplina, :titolo)
        .group_by { |na| [na.annocorso, na.sezioneanno, na.combinazione] }
    end
  end
end
