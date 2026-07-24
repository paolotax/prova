module Miur
  # Risolve il volume successivo dai roster MIUR nazionali dell'anno target:
  # stesso editore, disciplina compatibile, annocorso target, stesso titolo-base.
  # Serve alle adozioni concorrenza (libro_id nil, snapshot MIUR) che non hanno
  # un prosegui esplicito su Libro: il volume successivo non e' nel catalogo
  # proprio ma nei roster delle ALTRE scuole dell'anno nuovo.
  #
  # Ritorna { adozione_id => Esemplare } solo per i match DOMINANTI: fra le righe
  # candidate raggruppate per codiceisbn vince l'ISBN a frequenza massima se unico;
  # pareggio o zero candidati => non risolto (omesso dalla mappa).
  class VolumeSuccessivo
    # Riga esemplare del volume vincente: solo i campi che servono a costruire la
    # nuova Adozione. prezzo_euro mirror di Miur::Adozione#prezzo_euro.
    Esemplare = Struct.new(:codiceisbn, :titolo, :prezzo, keyword_init: true) do
      def prezzo_euro
        normalizzato = prezzo.to_s.tr(",", ".")
        return unless normalizzato.match?(/\A[0-9]+(\.[0-9]+)?\z/)
        BigDecimal(normalizzato)
      end
    end

    def initialize(anno:)
      @anno = anno
    end

    # sorgenti: enumerable di oggetti che rispondono a id/editore/disciplina/titolo
    # (Adozione o doppio equivalente). verso: annocorso target (String, es. "2").
    def risolvi(sorgenti, verso:)
      risultati = {}

      # Una query per gruppo [editore, disciplina]: aggrega i candidati per
      # (isbn, titolo, prezzo) direttamente in SQL, senza caricare le righe.
      sorgenti.group_by { |ad| [ad.editore, ad.disciplina] }.each do |(editore, disciplina), gruppo|
        next if editore.blank? || disciplina.blank?

        candidati = Miur::Adozione.where(
          anno_scolastico: @anno, tipogradoscuola: "EE", annocorso: verso.to_s,
          editore: editore, disciplina: discipline_compatibili(disciplina)
        ).group(:codiceisbn, :titolo, :prezzo).count

        gruppo.each do |ad|
          base = Libro.titolo_base(ad.titolo)
          per_isbn  = Hash.new(0)
          esemplari = {}

          candidati.each do |(isbn, titolo, prezzo), n|
            next if isbn.blank?
            next unless Libro.titolo_base(titolo) == base
            per_isbn[isbn] += n
            # Esemplare = la (titolo, prezzo) piu' frequente per quell'ISBN.
            corrente = esemplari[isbn]
            if corrente.nil? || n > corrente[:n]
              esemplari[isbn] = { n: n, riga: Esemplare.new(codiceisbn: isbn, titolo: titolo, prezzo: prezzo) }
            end
          end

          vincente = isbn_dominante(per_isbn)
          risultati[ad.id] = esemplari[vincente][:riga] if vincente
        end
      end

      risultati
    end

    private

    # Mirror di Libro#discipline_prosegui (app/models/libro.rb): stessa disciplina,
    # piu' l'eccezione primo biennio (IL LIBRO DELLA PRIMA CLASSE prosegue nel
    # SUSSIDIARIO (1° BIENNIO)). Tenere allineati.
    def discipline_compatibili(disciplina)
      if disciplina.to_s.match?(/LIBRO DELLA PRIMA/i)
        [disciplina, "SUSSIDIARIO (1° BIENNIO)"]
      else
        [disciplina]
      end
    end

    # ISBN a maggioranza stretta: vince solo se il massimo e' unico; pareggio => nil.
    def isbn_dominante(per_isbn)
      return if per_isbn.empty?
      max = per_isbn.values.max
      vincenti = per_isbn.select { |_, n| n == max }.keys
      vincenti.one? ? vincenti.first : nil
    end
  end
end
