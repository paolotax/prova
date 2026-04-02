class Clienti::Importer
  include ActiveModel::Model

  attr_reader :cliente, :action, :error

  def initialize(denominazione: nil, nome: nil, ragione_sociale: nil,
                 partita_iva: nil, piva: nil,
                 codice_fiscale: nil, cf: nil,
                 comune: nil, citta: nil,
                 indirizzo: nil, numero_civico: nil, cap: nil, provincia: nil,
                 email: nil, telefono: nil, pec: nil,
                 indirizzo_telematico: nil, sdi: nil,
                 tipo_cliente: nil, cognome: nil, nome_persona: nil,
                 nazione: nil, on_conflict: "update")
    @denominazione = denominazione || ragione_sociale || nome
    @partita_iva = normalize_piva(partita_iva || piva)
    @codice_fiscale = normalize_cf(codice_fiscale || cf)
    @comune = comune || citta
    @indirizzo = indirizzo
    @numero_civico = numero_civico
    @cap = cap
    @provincia = provincia
    @email = email&.downcase
    @telefono = telefono
    @pec = pec&.downcase
    @indirizzo_telematico = indirizzo_telematico || sdi
    @tipo_cliente = tipo_cliente
    @cognome = cognome
    @nome_persona = nome_persona
    @nazione = nazione
    @on_conflict = on_conflict
  end

  def import
    if @denominazione.blank?
      fail!("denominazione obbligatoria")
    else
      find_or_create_cliente
    end
    self
  end

  def ok?
    @error.nil?
  end

  def result
    if ok?
      { ok: true, action: action, cliente: cliente }
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

  def normalize_piva(value)
    return nil if value.blank?

    value.to_s.gsub(/[\s\-]/, "")
  end

  def normalize_cf(value)
    return nil if value.blank?

    value.to_s.gsub(/[\s\-]/, "").upcase
  end

  def find_or_create_cliente
    @cliente = find_existing

    if @cliente
      if @on_conflict == "skip"
        @action = "skipped"
        return true
      end

      assign_attributes
      @cliente.save!
      @action = "updated"
    else
      @cliente = Current.account.clienti.build(user: Current.user)
      assign_attributes
      @cliente.denominazione = @denominazione
      @cliente.partita_iva = @partita_iva if @partita_iva.present?
      @cliente.codice_fiscale = @codice_fiscale if @codice_fiscale.present?
      @cliente.save!
      @action = "created"
    end
    true
  rescue ActiveRecord::RecordInvalid => e
    fail!(e.message)
  end

  def find_existing
    if @partita_iva.present?
      Current.account.clienti.find_by(partita_iva: @partita_iva)
    elsif @codice_fiscale.present?
      Current.account.clienti.find_by(codice_fiscale: @codice_fiscale)
    end
  end

  def assign_attributes
    @cliente.denominazione = @denominazione if @denominazione.present?
    @cliente.partita_iva = @partita_iva if @partita_iva.present?
    @cliente.codice_fiscale = @codice_fiscale if @codice_fiscale.present?
    @cliente.comune = @comune if @comune.present?
    @cliente.indirizzo = @indirizzo if @indirizzo.present?
    @cliente.numero_civico = @numero_civico if @numero_civico.present?
    @cliente.cap = @cap if @cap.present?
    @cliente.provincia = @provincia if @provincia.present?
    @cliente.email = @email if @email.present?
    @cliente.telefono = @telefono if @telefono.present?
    @cliente.pec = @pec if @pec.present?
    @cliente.indirizzo_telematico = @indirizzo_telematico if @indirizzo_telematico.present?
    @cliente.tipo_cliente = @tipo_cliente if @tipo_cliente.present?
    @cliente.cognome = @cognome if @cognome.present?
    @cliente.nome = @nome_persona if @nome_persona.present?
    @cliente.nazione = @nazione if @nazione.present?
  end

  def fail!(message)
    @error = message
    false
  end
end
