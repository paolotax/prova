# Situazione di magazzino per l'export xlsx: una colonna per causale.
# Sostituisce Libro.crosstab: niente estensione crosstab(), bind params,
# solo documenti padre, scoping account. Pivot in Ruby.
class Libro::Situazione
  def initialize(account)
    @account = account
  end

  def causali
    @causali ||= Causale.order(:magazzino, :movimento, :tipo_movimento).pluck(:causale)
  end

  def righe
    quantita = quantita_per_libro_e_causale

    @account.libri.where(id: quantita.keys)
      .includes(:editore, :categoria).order(:titolo)
      .map do |libro|
        per_causale = quantita.fetch(libro.id, {})
        {
          "codice_isbn" => libro.codice_isbn,
          "titolo" => libro.titolo,
          "prezzo_in_cents" => libro.prezzo_in_cents,
          **causali.index_with { |causale| per_causale.fetch(causale, 0) },
          "gruppo" => libro.editore&.gruppo,
          "editore" => libro.editore&.editore,
          "adozioni_count" => libro.adozioni_count,
          "categoria" => libro.categoria&.nome_categoria,
          "classe" => libro.classe,
          "disciplina" => libro.disciplina,
          "id" => libro.id
        }
      end
  end

  private

  def quantita_per_libro_e_causale
    DocumentoRiga
      .joins(:riga, documento: :causale)
      .where(documenti: { account_id: @account.id, documento_padre_id: nil })
      .group("righe.libro_id", "causali.causale")
      .sum("righe.quantita")
      .each_with_object(Hash.new { |h, k| h[k] = {} }) do |((libro_id, causale), quantita), acc|
        acc[libro_id][causale] = quantita
      end
  end
end
