class Documenti::Creator
  include ActiveModel::Model

  attr_reader :documento, :error

  def initialize(clientable_value:, causale_nome:, note: nil, data_documento: nil, numero_documento: nil, righe_params: [])
    @clientable_value = clientable_value
    @causale_nome = causale_nome
    @note = note
    @data_documento = data_documento
    @numero_documento = numero_documento
    @righe_params = righe_params
  end

  def create
    resolve_clientable && resolve_causale && build_documento && add_righe && save_documento
    self
  end

  def ok?
    @error.nil?
  end

  def result
    if ok?
      result = {
        ok: true,
        documento_id: documento.id,
        numero_documento: documento.numero_documento,
        causale: @causale.causale,
        clientable: documento.clientable&.denominazione,
        totale_cents: documento.totale_cents,
        totale: documento.totale_cents ? "%.2f" % (documento.totale_cents / 100.0) : nil,
        totale_copie: documento.totale_copie,
        righe_count: documento.righe.size
      }
      if @from_padre
        result[:derivato_da] = {
          documento_id: @from_padre.id,
          causale: @from_padre.causale&.causale,
          numero_documento: @from_padre.numero_documento
        }
      end
      result
    else
      { ok: false, error: error }
    end
  end

  private

  def resolve_clientable
    return fail!("clientable_value obbligatorio") if @clientable_value.blank?

    @clientable = Appuntabile.find_appuntabile(@clientable_value)
    return fail!("destinatario '#{@clientable_value}' non trovato") unless @clientable
    true
  end

  def resolve_causale
    return fail!("causale obbligatoria") if @causale_nome.blank?

    @causale = Causale.find_by("causale ILIKE ?", @causale_nome.strip)
    return fail!("causale '#{@causale_nome}' non trovata") unless @causale
    true
  end

  def build_documento
    data = @data_documento.present? ? Date.parse(@data_documento.to_s) : Date.current
    num = parse_numero_documento

    padre = find_documento_padre
    if padre
      @documento = padre.genera_documento_derivato(@causale, {
        numero_documento: num,
        data_documento: data,
        note: @note,
        account: Current.account
      })
      @from_padre = padre
    else
      @documento = Current.account.documenti.build(
        user: Current.user,
        causale: @causale,
        clientable: @clientable,
        note: @note,
        data_documento: data,
        numero_documento: num
      )
    end
    true
  end

  def find_documento_padre
    # Cerca causali che hanno questa causale come successiva
    predecessori = Causale.select { |c| Array(c.causali_successive).include?(@causale.id.to_s) }
    return nil if predecessori.empty?

    # Cerca documenti aperti dello stesso clientable
    Current.account.documenti
      .where(clientable: @clientable, causale: predecessori)
      .where(documento_padre_id: nil)
      .order(data_documento: :desc)
      .first
  end

  def parse_numero_documento
    if @numero_documento.present?
      n = @numero_documento.to_s
      n = n[4..] if n.length > 7
      n.to_i
    else
      (Current.account.documenti
        .where(causale: @causale)
        .where("EXTRACT(YEAR FROM data_documento) = ?", Date.current.year)
        .maximum(:numero_documento) || 0).to_i + 1
    end
  end

  def add_righe
    # Se derivato dal padre, le righe sono già condivise
    return true if @from_padre

    @righe_params.each_with_index do |rp, i|
      libro = resolve_libro(rp, i) or return false

      prezzo_copertina = libro.prezzo_in_cents || 0
      sconto = (rp[:sconto] || 0).to_f
      prezzo = if rp[:prezzo_cents].present?
                 rp[:prezzo_cents].to_i
               else
                 prezzo_copertina
               end

      riga = Riga.new(
        libro: libro,
        quantita: (rp[:quantita] || 1).to_i,
        sconto: sconto,
        prezzo_cents: prezzo,
        prezzo_copertina_cents: prezzo_copertina
      )

      @documento.righe << riga
    end
    true
  end

  def resolve_libro(rp, index)
    if rp[:libro_id].present?
      libro = Current.account.libri.find_by(id: rp[:libro_id])
      return fail!("riga #{index + 1}: libro non trovato (id: #{rp[:libro_id]})") unless libro
      libro
    elsif rp[:codice_isbn].present?
      libro = Current.account.libri.find_by(codice_isbn: rp[:codice_isbn])
      return fail!("riga #{index + 1}: libro non trovato (ISBN: #{rp[:codice_isbn]})") unless libro
      libro
    elsif rp[:titolo].present?
      libro = Current.account.libri.search_all_word(rp[:titolo]).first
      return fail!("riga #{index + 1}: libro non trovato (titolo: #{rp[:titolo]})") unless libro
      libro
    else
      fail!("riga #{index + 1}: specificare libro_id, codice_isbn o titolo")
    end
  end

  def save_documento
    if @from_padre
      # Derivazione: le righe sono condivise dal padre
      unless @documento.save
        return fail!(@documento.errors.full_messages.join(", "))
      end
      @documento.reload
      @documento.ricalcola_totali! if @documento.respond_to?(:ricalcola_totali!)
      @documento.ensure_entry! if @documento.respond_to?(:ensure_entry!)

      # Il padre diventa figlio e viene chiuso
      @from_padre.update!(documento_padre_id: @documento.id)
      @from_padre.ensure_entry! if @from_padre.respond_to?(:ensure_entry!)
      @from_padre.close if @from_padre.respond_to?(:close) && !@from_padre.closed?
      @from_padre.eredita_stato_da_origini([@from_padre]) if @documento.respond_to?(:eredita_stato_da_origini)
    else
      @documento.totale_copie = @documento.righe.sum(&:quantita)
      @documento.totale_cents = @documento.righe.sum(&:importo_cents)

      unless @documento.save
        return fail!(@documento.errors.full_messages.join(", "))
      end
    end
    true
  end

  def fail!(message)
    @error = message
    false
  end
end
