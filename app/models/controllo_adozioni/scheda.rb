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
