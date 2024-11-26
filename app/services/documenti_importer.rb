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
   
    errors.add(:base, "Errore nel file XML") unless doc

    cliente_id = Current.user.clienti.find_by(partita_iva: doc.xpath('//CessionarioCommittente/DatiAnagrafici/IdFiscaleIVA/IdCodice').text)&.id 
    errors.add(:base, "Cliente non trovato") unless cliente_id
    
    causale_id = Causale.find_by(causale: doc.xpath('//DatiGeneraliDocumento/TipoDocumento').text)&.id
    errors.add(:base, "Causale non trovata") unless causale_id
    
    numero_documento = parse_numero_documento(doc.xpath('//DatiGeneraliDocumento/Numero').text)
    errors.add(:base, "Numero documento non trovato") unless numero_documento

    if Current.user.documenti.find_by(numero_documento: numero_documento, causale_id: causale_id, clientable_id: cliente_id)
      errors.add(:base, "Documento già presente")
      return
    end 

    if cliente_id
      
      documento = Current.user.documenti.create(
        clientable_type:  "Cliente",
        clientable_id: cliente_id,
        causale_id: causale_id,
        numero_documento: numero_documento,  
        data_documento: Date.parse(doc.xpath('//DatiGeneraliDocumento/Data').text),
      )
      
      righe_path = '//DettaglioLinee'
  
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

        libro_id = Current.user.libri.find_by(codice_isbn: codice_valore)&.id
        if libro_id
          documento.documento_righe.build(posizione: posizione).build_riga(
            libro_id:  libro_id,              
            prezzo_cents:  (element.xpath("./PrezzoUnitario").text.to_f * 100).to_i,
            quantita:  quantita,
            sconto:  element.xpath("./ScontoMaggiorazione/Percentuale").text || 0.0
          )
          @imported_count += 1
        end
        
        
      end

      unless documento.save
        errors.add(:base, "Errore nel salvataggio del documento")
      else
        @imported_count += 1
        @documento = documento
      end
    end
  end





  def import_excel!
    xlsx = Roo::Spreadsheet.open(file.path, { csv_options: { encoding: 'bom|utf-8', col_sep: ";" } })
    xlsx.default_sheet = xlsx.sheets.first 
    
    header = xlsx.row(1) 
    header.map! { |h| h.downcase.gsub(" ", "_").to_sym }

    documento = Current.user.documenti.find(documento_id)

    2.upto(xlsx.last_row) do |line|  
      row_data = Hash[header.zip xlsx.row(line)]

      codice   = row_data[:codice_isbn] || row_data[:ean] || row_data[:isbn]
      libro    = Current.user.libri.find_by(codice_isbn: codice)
      quantita = row_data[:quantita] || row_data[:qta]
      sconto   = row_data[:sconto] || 0.0
      
      documento_riga = documento.documento_righe.build

      riga = documento_riga.build_riga(libro: libro, sconto: sconto, quantita: quantita)
           
      assign_from_row_2(row_data, riga)

      if documento_riga.save
          @imported_count += 1
          @documento = documento
      else
        @errors_count += 1
        errors.add(:base, "Line #{$.} - #{riga.errors.full_messages.join(", ")}")
        #return false
      end
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
          
        row[key] = check_prezzo(row[key]) if key == :prezzo

        if riga.respond_to?("#{key}=") 
          riga.send("#{key}=", row[key])
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