class Persone::Importer
  include ActiveModel::Model

  attr_reader :persona, :matched_scuola, :matched_classi, :action, :changes, :error, :suggestions

  def initialize(cognome:, nome: nil, email: nil, cellulare: nil, telefono: nil, scuola: nil, classi: nil)
    @cognome = cognome
    @nome = nome
    @email = email
    @cellulare = cellulare
    @telefono = telefono
    @scuola_query = scuola
    @classi_input = Array(classi)
    @changes = []
    @matched_classi = []
  end

  def import
    resolve_scuola && resolve_classi && find_or_create_persona && assign_classi
    self
  end

  def ok?
    @error.nil?
  end

  def result
    if ok?
      {
        ok: true,
        action: action,
        persona: { id: persona.id, cognome: persona.cognome, nome: persona.nome, email: persona.email,
                   scuola: persona.scuola&.denominazione, appuntabile_value: "Persona:#{persona.id}" },
        matched_scuola: matched_scuola.denominazione,
        matched_classi: matched_classi.map(&:nome_completo),
        changes: changes
      }
    else
      { ok: false, error: error, cognome: @cognome, nome: @nome, suggestions: suggestions }
    end
  end

  # Batch import
  def self.import_batch(persone_data)
    results = []
    errors = []

    persone_data.each_with_index do |data, index|
      importer = new(**data.symbolize_keys).import
      if importer.ok?
        results << importer.result.merge(index: index)
      else
        errors << importer.result.merge(index: index)
      end
    end

    created = results.count { |r| r[:action] == "created" }
    updated = results.count { |r| r[:action] == "updated" }
    unchanged = results.count { |r| r[:action] == "unchanged" }

    {
      ok: errors.empty?,
      summary: "#{results.size} persone importate: #{created} create, #{updated} aggiornate, #{unchanged} invariate, #{errors.size} errori",
      results: results,
      errors: errors
    }
  end

  private

  def resolve_scuola
    return fail!("scuola non specificata") if @scuola_query.blank?

    candidates = Current.account.scuole.search_all_word(@scuola_query).limit(3)
    return fail!("scuola '#{@scuola_query}' non trovata") if candidates.empty?

    @matched_scuola = candidates.first
    true
  rescue PgSearch::EmptyQueryError
    fail!("scuola '#{@scuola_query}' non trovata")
  end

  def resolve_classi
    @classi_input.each do |classe_str|
      anno, sezione = parse_classe(classe_str)
      return fail!("formato classe non valido: '#{classe_str}' (usa es. 3A)") unless anno

      classe = matched_scuola.classi.find_by(anno_corso: anno, sezione: sezione)
      return fail!("classe #{classe_str} non trovata in #{matched_scuola.denominazione}") unless classe

      @matched_classi << classe
    end
    true
  end

  def parse_classe(str)
    match = str.to_s.strip.upcase.match(/\A(\d)([A-Z]+)\z/)
    match ? [match[1], match[2]] : nil
  end

  def find_or_create_persona
    @persona = matched_scuola.persone.find_or_initialize_by(
      cognome: @cognome,
      account: Current.account
    )

    # Disambigua per nome se presente
    if @nome.present? && @persona.persisted? && @persona.nome.present? && @persona.nome.downcase != @nome.downcase
      # Cognome uguale ma nome diverso — cerca match esatto
      exact = matched_scuola.persone.where(account: Current.account)
                .where("cognome ILIKE ? AND nome ILIKE ?", @cognome, @nome).first
      if exact
        @persona = exact
      else
        @persona = Current.account.persone.build(cognome: @cognome, nome: @nome, scuola: matched_scuola)
      end
    end

    if @persona.new_record?
      @persona.nome = @nome
      @persona.email = @email
      @persona.cellulare = @cellulare
      @persona.telefono = @telefono
      @persona.scuola = matched_scuola
      @persona.save!
      @action = "created"
    else
      upsert_fields
      @action = @changes.any? ? "updated" : "unchanged"
    end
    true
  end

  def upsert_fields
    { nome: @nome, email: @email, cellulare: @cellulare, telefono: @telefono }.each do |field, value|
      next if value.blank?
      next if @persona.send(field).present?

      @persona.send(:"#{field}=", value)
      @changes << "#{field} aggiunto"
    end
    @persona.save! if @persona.changed?
  end

  def assign_classi
    matched_classi.each do |classe|
      next if @persona.classi.include?(classe)

      PersonaClasse.find_or_create_by!(persona: @persona, classe: classe)
      @changes << "classe #{classe.nome_breve} aggiunta"
    end
    @action = "updated" if @action == "unchanged" && @changes.any?
    true
  end

  def fail!(message, suggestions: nil)
    @error = message
    @suggestions = suggestions
    false
  end
end
