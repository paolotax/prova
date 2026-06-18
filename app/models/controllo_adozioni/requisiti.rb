module ControlloAdozioni
  module Requisiti
    # Un requisito è soddisfatto se le discipline presenti soddisfano la sua regola.
    # prezzo_disciplina: disciplina PrezzoMinisteriale da cui leggere il prezzo per il tetto.
    Requisito = Struct.new(:chiave, :regola, :prezzo_disciplina, keyword_init: true) do
      # discipline_presenti: array di stringhe disciplina dei libri daacquist della classe
      def soddisfatto?(discipline_presenti)
        regola.call(discipline_presenti.map { |d| d.to_s.strip.upcase })
      end
    end

    def self.match?(discipline, *patterns)
      discipline.any? { |d| patterns.any? { |p| d.include?(p) } }
    end

    INGLESE = Requisito.new(chiave: :inglese,
      regola: ->(d) { match?(d, "LINGUA INGLESE") },
      prezzo_disciplina: "LINGUA INGLESE")

    RELIGIONE_ALT = Requisito.new(chiave: :religione_alt,
      regola: ->(d) { match?(d, "RELIGIONE", "ADOZIONE ALTERNATIVA") },
      prezzo_disciplina: "RELIGIONE")

    LIBRO_PRIMA = Requisito.new(chiave: :libro_prima_classe,
      regola: ->(d) { match?(d, "IL LIBRO DELLA PRIMA CLASSE") },
      prezzo_disciplina: "IL LIBRO DELLA PRIMA CLASSE")

    SUSS_1BIENNIO = Requisito.new(chiave: :sussidiario_1biennio,
      regola: ->(d) { match?(d, "SUSSIDIARIO (1° BIENNIO)") },
      prezzo_disciplina: "SUSSIDIARIO (1° BIENNIO)")

    SUSS_LINGUAGGI = Requisito.new(chiave: :sussidiario_linguaggi,
      regola: ->(d) { match?(d, "SUSSIDIARIO DEI LINGUAGGI") },
      prezzo_disciplina: "SUSSIDIARIO DEI LINGUAGGI")

    # Unico OPPURE (antropologico E scientifico). Per il tetto si usa il prezzo dell'unico.
    SUSS_DISCIPLINE = Requisito.new(chiave: :sussidiario_discipline,
      regola: ->(d) {
        unico = d.any? { |x| x.include?("SUSSIDIARIO DELLE DISCIPLINE") && !x.include?("AMBITO") }
        antro = match?(d, "AMBITO ANTROPOLOGICO")
        scien = match?(d, "AMBITO SCIENTIFICO")
        unico || (antro && scien)
      },
      prezzo_disciplina: "SUSSIDIARIO DELLE DISCIPLINE")

    PER_CLASSE = {
      "1" => [LIBRO_PRIMA, INGLESE, RELIGIONE_ALT],
      "2" => [SUSS_1BIENNIO, INGLESE],
      "3" => [SUSS_1BIENNIO, INGLESE],
      "4" => [SUSS_LINGUAGGI, SUSS_DISCIPLINE, INGLESE, RELIGIONE_ALT],
      "5" => [SUSS_LINGUAGGI, SUSS_DISCIPLINE, INGLESE],
    }.freeze

    def self.per_classe(annocorso)
      PER_CLASSE.fetch(annocorso.to_s, [])
    end

    # Tetto in cents per una classe, dato un hash {disciplina => prezzo_cents} di PrezzoMinisteriale.
    # Somma un solo prezzo di riferimento per requisito (evita il doppio conteggio della coppia ambiti).
    def self.tetto_cents(annocorso, prezzi_pm)
      per_classe(annocorso).sum { |r| prezzi_pm[r.prezzo_disciplina].to_i }
    end
  end
end
