module ControlloAdozioni
  # Anteprima delle adozioni MIUR di una scuola, una sezione per classe, nello
  # stesso formato del PDF ufficiale "Elenco dei libri di testo adottati o
  # consigliati" scaricabile dal sito del MIUR.
  #
  # fonte "new" legge da new_adozioni (snapshot dell'anno nuovo, non ancora
  # promosso); fonte "import" legge da import_adozioni (l'anno gia' importato).
  # I valori delle righe sono quelli grezzi MIUR (maiuscolo, non titleizzati):
  # il PDF ufficiale non li presenta, li riporta cosi' come scaricati.
  class Anteprima
    FONTI = %w[new import].freeze

    Riga = Struct.new(
      :disciplina, :codice_isbn, :autori, :titolo, :sottotitolo, :volume,
      :editore, :prezzo, :nuova_adozione, :da_acquistare, :consigliato,
      keyword_init: true
    )

    ClasseGruppo = Struct.new(:annocorso, :sezioneanno, :combinazione, :righe, keyword_init: true)

    Intestazione = Struct.new(
      :denominazione, :indirizzo, :cap, :comune, :tipo_scuola, :anno_scolastico,
      keyword_init: true
    ) do
      def indirizzo_formattato
        [indirizzo, "#{cap} #{comune}".strip].reject(&:blank?)
      end
    end

    attr_reader :codicescuola, :fonte

    def initialize(codicescuola:, fonte: "new")
      @codicescuola = codicescuola.to_s
      @fonte = FONTI.include?(fonte.to_s) ? fonte.to_s : "new"
    end

    def fonte_label
      fonte == "import" ? "Anno corrente (import_adozioni)" : "Anno nuovo (MIUR, non ancora promosso)"
    end

    def intestazione
      @intestazione ||= fonte == "import" ? intestazione_da_import : intestazione_da_new
    end

    def classi
      @classi ||= fonte == "import" ? classi_da_import : classi_da_new
    end

    def disponibile?
      classi.any?
    end

    private

    def intestazione_da_new
      scuola = NewScuola.where(codice_scuola: codicescuola).order(anno_scolastico: :desc).first
      anno = NewAdozione.where(codicescuola: codicescuola).maximum(:anno_scolastico) || scuola&.anno_scolastico
      Intestazione.new(
        denominazione: scuola&.denominazione, indirizzo: scuola&.indirizzo, cap: scuola&.cap,
        comune: scuola&.comune, tipo_scuola: scuola&.tipo_scuola, anno_scolastico: anno
      )
    end

    def intestazione_da_import
      scuola = ImportScuola.find_by(CODICESCUOLA: codicescuola)
      anno = ImportAdozione.where(CODICESCUOLA: codicescuola).maximum(:anno_scolastico) || scuola&.ANNOSCOLASTICO
      Intestazione.new(
        denominazione: scuola&.DENOMINAZIONESCUOLA, indirizzo: scuola&.INDIRIZZOSCUOLA, cap: scuola&.CAPSCUOLA,
        comune: scuola&.DESCRIZIONECOMUNE, tipo_scuola: scuola&.DESCRIZIONETIPOLOGIAGRADOISTRUZIONESCUOLA,
        anno_scolastico: anno
      )
    end

    def classi_da_new
      NewAdozione.where(codicescuola: codicescuola)
                 .order(:annocorso, :sezioneanno, :combinazione, :disciplina, :titolo)
                 .group_by { |na| [na.annocorso, na.sezioneanno, na.combinazione] }
                 .map do |(annocorso, sezioneanno, combinazione), righe|
        ClasseGruppo.new(annocorso: annocorso, sezioneanno: sezioneanno, combinazione: combinazione,
                         righe: righe.map { |na| riga_da_new(na) })
      end
    end

    def riga_da_new(na)
      Riga.new(
        disciplina: na.disciplina, codice_isbn: na.codiceisbn, autori: na.autori,
        titolo: na.titolo, sottotitolo: na.sottotitolo, volume: na.volume,
        editore: na.editore, prezzo: na.prezzo_euro,
        nuova_adozione: si_no(na.nuovaadoz), da_acquistare: si_no(na.daacquist),
        consigliato: si_no(na.consigliato)
      )
    end

    def classi_da_import
      ImportAdozione.where(CODICESCUOLA: codicescuola)
                    .order(:ANNOCORSO, :SEZIONEANNO, :COMBINAZIONE, :DISCIPLINA, :TITOLO)
                    .group_by { |ia| [ia.ANNOCORSO, ia.SEZIONEANNO, ia.COMBINAZIONE] }
                    .map do |(annocorso, sezioneanno, combinazione), righe|
        ClasseGruppo.new(annocorso: annocorso, sezioneanno: sezioneanno, combinazione: combinazione,
                         righe: righe.map { |ia| riga_da_import(ia) })
      end
    end

    def riga_da_import(ia)
      Riga.new(
        disciplina: ia.DISCIPLINA, codice_isbn: ia.CODICEISBN, autori: ia.AUTORI,
        titolo: ia.TITOLO, sottotitolo: ia.SOTTOTITOLO, volume: ia.VOLUME,
        editore: ia.EDITORE, prezzo: parse_prezzo(ia.PREZZO),
        nuova_adozione: si_no(ia.NUOVAADOZ), da_acquistare: si_no(ia.DAACQUIST),
        consigliato: si_no(ia.CONSIGLIATO)
      )
    end

    def si_no(value)
      value.to_s.match?(/\As/i) ? "Si" : "No"
    end

    def parse_prezzo(value)
      normalizzato = value.to_s.tr(",", ".")
      return unless normalizzato.match?(/\A[0-9]+(\.[0-9]+)?\z/)

      BigDecimal(normalizzato)
    end
  end
end
