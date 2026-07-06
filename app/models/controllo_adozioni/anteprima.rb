module ControlloAdozioni
  # Anteprima delle adozioni MIUR di una scuola, una sezione per classe, nello
  # stesso formato del PDF ufficiale "Elenco dei libri di testo adottati o
  # consigliati" scaricabile dal sito del MIUR.
  #
  # Parametrizzata per anno scolastico (es. "202627"): le righe vengono lette da
  # Miur::Adozione.per_anno(anno). I valori sono quelli grezzi MIUR (maiuscolo,
  # non titleizzati): il PDF ufficiale non li presenta, li riporta cosi' come
  # scaricati.
  class Anteprima
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

    attr_reader :codicescuola, :anno

    def initialize(codicescuola:, anno: Miur.anno_corrente)
      @codicescuola = codicescuola.to_s
      @anno = anno.to_s
    end

    # Etichetta leggibile dell'anno scolastico, es. "202627" -> "2026/27".
    def anno_label
      return if anno.blank?

      "#{anno[0, 4]}/#{anno[4, 2]}"
    end

    def intestazione
      @intestazione ||= intestazione_da_miur || intestazione_da_import
    end

    def classi
      @classi ||= adozioni.group_by { |a| [a.annocorso, a.sezioneanno, a.combinazione] }
                          .map do |(annocorso, sezioneanno, combinazione), righe|
        ClasseGruppo.new(annocorso: annocorso, sezioneanno: sezioneanno, combinazione: combinazione,
                         righe: righe.map { |a| riga_da(a) })
      end
    end

    def disponibile?
      classi.any?
    end

    private

    def adozioni
      @adozioni ||= Miur::Adozione.per_anno(anno)
                                  .where(codicescuola: codicescuola)
                                  .order(:annocorso, :sezioneanno, :combinazione, :disciplina, :titolo)
                                  .to_a
    end

    # Intestazione dallo snapshot MIUR dell'anno richiesto (miur_scuole).
    def intestazione_da_miur
      scuola = Miur::Scuola.per_anno(anno).find_by(codice_scuola: codicescuola)
      return unless scuola

      Intestazione.new(
        denominazione: scuola.denominazione, indirizzo: scuola.indirizzo, cap: scuola.cap,
        comune: scuola.comune, tipo_scuola: scuola.tipo_scuola, anno_scolastico: anno
      )
    end

    # Fallback sull'anagrafe durevole per gli anni senza snapshot in miur_scuole.
    def intestazione_da_import
      scuola = ImportScuola.find_by(CODICESCUOLA: codicescuola)
      Intestazione.new(
        denominazione: scuola&.DENOMINAZIONESCUOLA, indirizzo: scuola&.INDIRIZZOSCUOLA, cap: scuola&.CAPSCUOLA,
        comune: scuola&.DESCRIZIONECOMUNE, tipo_scuola: scuola&.DESCRIZIONETIPOLOGIAGRADOISTRUZIONESCUOLA,
        anno_scolastico: anno
      )
    end

    def riga_da(a)
      Riga.new(
        disciplina: a.disciplina, codice_isbn: a.codiceisbn, autori: a.autori,
        titolo: a.titolo, sottotitolo: a.sottotitolo, volume: a.volume,
        editore: a.editore, prezzo: a.prezzo_euro,
        nuova_adozione: si_no(a.nuovaadoz), da_acquistare: si_no(a.daacquist),
        consigliato: si_no(a.consigliato)
      )
    end

    def si_no(value)
      value.to_s.match?(/\As/i) ? "Si" : "No"
    end
  end
end
