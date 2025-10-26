class DocumentiImporter

  include ActionView::Helpers::TextHelper
  include ActiveModel::Model

  attr_accessor :file, :imported_count, :updated_count, :errors_count, :import_method, :documento, :documento_id

  def initialize(attributes = {})
    super
    @imported_count = 0
    @updated_count = 0
    @errors_count = 0
  end

  def process!
    doc = Nokogiri::XML(File.open(file.path))
   
    unless doc
      errors.add(:base, "Errore nel file XML")
      return false
    end

    partita_iva = doc.xpath('//CessionarioCommittente/DatiAnagrafici/IdFiscaleIVA/IdCodice').text
    cliente = Current.user.clienti.find_by(partita_iva: partita_iva)
    unless cliente
      errors.add(:base, "Cliente non trovato con P.IVA: #{partita_iva}")
      return false
    end
    
    tipo_documento = doc.xpath('//DatiGeneraliDocumento/TipoDocumento').text
    causale = Causale.find_by(causale: tipo_documento)
    unless causale
      errors.add(:base, "Causale '#{tipo_documento}' non trovata nel sistema")
      return false
    end
    
    numero_documento = parse_numero_documento(doc.xpath('//DatiGeneraliDocumento/Numero').text)
    unless numero_documento.present?
      errors.add(:base, "Numero documento non trovato nel file XML")
      return false
    end

    if Current.user.documenti.find_by(numero_documento: numero_documento, causale_id: causale.id, clientable_id: cliente.id)
      errors.add(:base, "Documento n. #{numero_documento} già presente per questo cliente")
      return false
    end 

    if cliente
      
      documento = Current.user.documenti.create(
        clientable_type:  "Cliente",
        clientable_id: cliente.id,
        causale_id: causale.id,
        numero_documento: numero_documento,  
        data_documento: Date.parse(doc.xpath('//DatiGeneraliDocumento/Data').text),
      )
      
      righe_path = '//DettaglioLinee'
      righe_importate = 0
      righe_saltate = []
  
      doc.xpath(righe_path).each do |element|
        
        quantita = element.xpath("./Quantita").text       
        if quantita == ''  
          quantita = '0' 
        end

        posizione = element.xpath("./NumeroLinea").text
        
        codice_articoli = element.xpath("./CodiceArticolo")

        # Verifica se ci sono duplicati
        if codice_articoli.size > 1
          # Se ci sono duplicati, seleziona il primo o il secondo
          codice_valore = codice_articoli[0].xpath("./CodiceValore").text # Primo CodiceArticolo
          # codice_valore = codice_articoli[1].xpath("./CodiceValore").text # Secondo CodiceArticolo (se necessario)
        else
          # Se non ci sono duplicati, seleziona il CodiceValore normalmente
          codice_valore = codice_articoli.xpath("./CodiceValore").text
        end

        libro = Current.user.libri.find_by(codice_isbn: codice_valore)
        if libro
          documento.documento_righe.build(posizione: posizione).build_riga(
            libro_id:  libro.id,              
            prezzo_cents:  (element.xpath("./PrezzoUnitario").text.to_f * 100).to_i || 0,
            quantita:  quantita,
            sconto:  element.xpath("./ScontoMaggiorazione/Percentuale").text || 0.0
          )
          righe_importate += 1
        else
          descrizione = element.xpath("./Descrizione").text
          righe_saltate << "Riga #{posizione}: #{codice_valore} - #{descrizione}"
        end
        
        
      end

      unless documento.save
        errors.add(:base, "Errore nel salvataggio del documento: #{documento.errors.full_messages.join(', ')}")
        return false
      else
        @imported_count = righe_importate
        @documento = documento

        # Ricalcola totali del documento dopo tutte le importazioni
        documento.reload
        documento.ricalcola_totali!

        if righe_saltate.any?
          errors.add(:base, "#{righe_saltate.count} righe non importate (articoli non trovati nel catalogo)")
          righe_saltate.first(5).each do |riga|
            errors.add(:base, riga)
          end
          if righe_saltate.count > 5
            errors.add(:base, "... e altre #{righe_saltate.count - 5} righe")
          end
        end
      end
    end
  end





  def import_excel!
    xlsx = Roo::Spreadsheet.open(file.path, { csv_options: { encoding: 'bom|utf-8', col_sep: ";" } })
    xlsx.default_sheet = xlsx.sheets.first

    header = xlsx.row(1)
    header.map! { |h| h.downcase.gsub(" ", "_").to_sym }

    documento = Current.user.documenti.find(documento_id)
    righe_con_errori = []

    2.upto(xlsx.last_row) do |line|
      row_data = Hash[header.zip xlsx.row(line)]

      codice   = row_data[:codice_isbn] || row_data[:ean] || row_data[:isbn]

      # Salta la riga se non c'è un codice ISBN
      if codice.blank?
        @errors_count += 1
        righe_con_errori << "Riga #{line}: Codice ISBN mancante"
        next
      end

      libro = Current.user.libri.find_by(codice_isbn: codice)

      # Se il libro non esiste, crealo con dati minimi
      unless libro
        titolo = row_data[:titolo] || row_data[:descrizione] || "Libro #{codice}"
        categoria = Categoria.find_or_create_by(nome_categoria: "Da completare", user_id: Current.user.id)

        libro = Current.user.libri.create(
          codice_isbn: codice,
          titolo: titolo,
          categoria: categoria,
          prezzo_in_cents: row_data[:prezzo].present? ? (row_data[:prezzo].to_f * 100).to_i : 0
        )

        unless libro.persisted?
          @errors_count += 1
          righe_con_errori << "Riga #{line}: Impossibile creare libro - #{libro.errors.full_messages.join(", ")}"
          next
        end
      end

      # Quantità: usa quella del file, se mancante usa 1
      quantita = row_data[:quantità] || row_data[:quantita] || row_data[:qta] || 1

      # Prezzo: usa quello del file, se mancante usa quello del libro, se nuovo record usa 0
      if row_data[:prezzo].present?
        prezzo_cents = (row_data[:prezzo].to_f * 100).to_i
      elsif libro&.prezzo_in_cents.present?
        prezzo_cents = libro.prezzo_in_cents
      else
        prezzo_cents = 0
      end

      # Sconto: usa quello del file, se mancante usa 0.0
      sconto = row_data[:sconto].present? ? row_data[:sconto].to_f : 0.0

      documento_riga = documento.documento_righe.build

      riga = documento_riga.build_riga(libro: libro, sconto: sconto, quantita: quantita, prezzo_cents: prezzo_cents)

      assign_from_row_2(row_data, riga)

      if documento_riga.save
          @imported_count += 1
          @documento = documento
      else
        @errors_count += 1
        righe_con_errori << "Riga #{line}: #{riga.errors.full_messages.join(", ")}"
        #return false
      end
    end

    if righe_con_errori.any?
      errors.add(:base, "#{righe_con_errori.count} righe con errori")
      righe_con_errori.first(5).each do |errore|
        errors.add(:base, errore)
      end
      if righe_con_errori.count > 5
        errors.add(:base, "... e altre #{righe_con_errori.count - 5} righe con errori")
      end
    end

    # Ricalcola totali del documento dopo tutte le importazioni
    if documento.present?
      documento.reload
      documento.ricalcola_totali!
    end

  end

  def flash_message
    if @imported_count > 0 || @updated_count > 0
      pluralize(@imported_count, 'riga importato', 'libri importati') + " e " + 
      pluralize(@updated_count, 'riga aggiornato', 'libri aggiornati')
    else
      pluralize(@errors_count, 'riga errato', 'libri errati') + 
      " " + errors.full_messages[0..10].join(", ").html_safe + " " +
      "Nessun riga importato"
    end
  end

  def save
    unless import_method == "xlsx_csv"
      process!
    else
      import_excel!
    end
    errors.none?
  end

  private

    def assign_from_row_2(row, riga)
      row.keys.each do |key|
        # Salta chiavi che non vogliamo sovrascrivere
        next if [:codice_isbn, :ean, :isbn, :quantità, :quantita, :qta].include?(key)

        value = row[key]

        # Salta valori nil o blank
        next if value.nil? || (value.respond_to?(:empty?) && value.empty?)

        value = check_prezzo(value) if key == :prezzo

        if riga.respond_to?("#{key}=")
          riga.send("#{key}=", value)
        end
      end
    end

    def check_prezzo(prezzo)
      if prezzo.is_a? String
        prezzo = prezzo.gsub("€","").gsub(",",".").strip
      end
      prezzo.to_s
    end


    def assign_from_row(row)
 
      codice_isbn = row[:codice_isbn] || row["codice_isbn"]
      user_id = Current.user.id
      riga = riga.where(codice_isbn: codice_isbn, user_id: user_id).first_or_initialize
      unless riga.new_record?
        if row[:titolo] then row.delete(:titolo) end
        if row["titolo"] then row.delete("titolo") end
      end
      riga.assign_attributes row.to_hash
      riga
    end


    def parse_numero_documento(numero_documento)
      # numero_documento.split(" ")[1].split("/")[0].to_i
      numero_documento.gsub(/\D/, '')
    end

 

end