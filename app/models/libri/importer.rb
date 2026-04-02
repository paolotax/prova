class Libri::Importer
  include ActiveModel::Model

  attr_reader :libro, :action, :error

  def initialize(isbn: nil, codice_isbn: nil, titolo: nil, prezzo: nil, prezzo_in_cents: nil,
                 editore: nil, editore_id: nil, categoria: nil, classe: nil, disciplina: nil,
                 collana: nil, cm: nil, on_conflict: "update")
    @isbn = normalize_isbn(isbn || codice_isbn)
    @titolo = titolo
    @prezzo_in_cents = resolve_prezzo(prezzo, prezzo_in_cents)
    @editore_id = resolve_editore(editore, editore_id)
    @categoria_name = categoria
    @classe = classe
    @disciplina = disciplina
    @collana = collana
    @cm = cm
    @on_conflict = on_conflict
  end

  def import
    if @isbn.blank?
      fail!("isbn obbligatorio")
    else
      find_or_create_libro
    end
    self
  end

  def ok?
    @error.nil?
  end

  def result
    if ok?
      { ok: true, action: action, libro: libro }
    else
      { ok: false, error: error }
    end
  end

  def batch_result
    {
      imported: action == "created" ? 1 : 0,
      updated: action == "updated" ? 1 : 0,
      skipped: action == "skipped" ? 1 : 0,
      errors: ok? ? [] : [result[:error]]
    }
  end

  # Batch import
  def self.import_batch(items, on_conflict: "update")
    counters = { imported: 0, updated: 0, skipped: 0, errors: [] }

    items.each do |data|
      importer = new(**data.symbolize_keys, on_conflict: on_conflict).import
      if importer.ok?
        case importer.action
        when "created"  then counters[:imported] += 1
        when "updated"  then counters[:updated] += 1
        when "skipped"  then counters[:skipped] += 1
        end
      else
        counters[:errors] << importer.error
      end
    end

    counters
  end

  private

  def normalize_isbn(value)
    return nil if value.blank?

    value.to_s.gsub(/[\s\-]/, "")
  end

  def resolve_prezzo(prezzo_string, prezzo_cents)
    return prezzo_cents unless prezzo_cents.nil?
    return nil if prezzo_string.blank?

    normalized = prezzo_string.to_s.gsub(",", ".")
    begin
      (BigDecimal(normalized) * 100).to_i
    rescue ArgumentError
      nil
    end
  end

  def resolve_editore(editore_input, editore_id_input)
    return editore_id_input if editore_id_input.present?
    return nil if editore_input.blank?

    # Numeric string or integer → treat as ID
    if editore_input.to_s.match?(/\A\d+\z/)
      editore_input.to_i
    else
      Editore.find_or_create_by!(editore: editore_input).id
    end
  end

  def resolve_categoria
    Categoria.resolve(@categoria_name, user: Current.user, account: Current.account)
  end

  def find_or_create_libro
    @libro = Current.account.libri.find_by(codice_isbn: @isbn)

    if @libro
      if @on_conflict == "skip"
        @action = "skipped"
        return true
      end

      assign_attributes
      @libro.save!
      @action = "updated"
    else
      @libro = Current.account.libri.build(codice_isbn: @isbn, user: Current.user)
      assign_attributes
      @libro.categoria ||= resolve_categoria
      @libro.save!
      @action = "created"
    end
    true
  rescue ActiveRecord::RecordInvalid => e
    fail!(e.message)
  end

  def assign_attributes
    @libro.titolo = @titolo if @titolo.present?
    @libro.prezzo_in_cents = @prezzo_in_cents unless @prezzo_in_cents.nil?
    @libro.editore_id = @editore_id if @editore_id.present?
    @libro.classe = @classe if @classe.present?
    @libro.disciplina = @disciplina if @disciplina.present?
    @libro.collana = @collana if @collana.present?
    @libro.cm = @cm if @cm.present?
  end

  def fail!(message)
    @error = message
    false
  end
end
