class DocumentiImporter

  include ActionView::Helpers::TextHelper
  include ActiveModel::Model

  attr_accessor :file, :imported_count, :updated_count, :errors_count, :import_method, :documento

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
        
        libro_id = Current.user.libri.find_by(codice_isbn: element.xpath("./CodiceArticolo/CodiceValore").text)&.id
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

  def import_xml
       
    # Specifica la directory contenente i file XML
    xml_dir = File.join('_xml/*.xml') 
    
    # Loop attraverso i file XML nella directory
    Dir.glob(xml_dir).each do |file|
      
      doc = Nokogiri::XML(File.open(file))

      cliente_id = Current.user.clienti.find_by(partita_iva: doc.xpath('//CessionarioCommittente/DatiAnagrafici/IdFiscaleIVA/IdCodice').text)&.id
      unless cliente_id
        raise "Cliente non trovato"
      end

      if cliente_id
        
        documento = Current.user.documenti.create(
          
          clientable_type:  "Cliente",
          clientable_id: cliente_id,

          causale_id: Causale.find_by(causale: doc.xpath('//DatiGeneraliDocumento/TipoDocumento').text)&.id,
          numero_documento: parse_numero_documento(doc.xpath('//DatiGeneraliDocumento/Numero').text),  
          data_documento: Date.parse(doc.xpath('//DatiGeneraliDocumento/Data').text),
        )
        
        righe_path = '//DettaglioLinee'
    
        doc.xpath(righe_path).each do |element|
          
          quantita = element.xpath("./Quantita").text       
          if quantita == ''  
            quantita = '0' 
          end

          posizione = element.xpath("./NumeroLinea").text
          libro_id = Current.user.libri.find_by(codice_isbn: element.xpath("./CodiceArticolo/CodiceValore").text)&.id          

          #puts libro_id

          if libro_id
            documento.documento_righe.build(posizione: posizione).build_riga(
              libro_id:  libro_id,              
              prezzo_cents:  (element.xpath("./PrezzoUnitario").text.to_f * 100).to_i,
              quantita:  quantita,
              sconto:  element.xpath("./ScontoMaggiorazione/Percentuale").text || 0.0
            )
          end
          
          
        end
        documento.save
      end

    end

  end

  def import_csv

    #documento = Current.user.documenti.build
    
    SmarterCSV.process(file.path) do |row|
      
      riga = assign_from_row(row.first)
      if riga.save
        if riga.previously_new_record?
          @imported_count += 1
        else
          @updated_count += 1
        end
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
      " " + errors.full_messages.join(", ").html_safe + " " +
      "Nessun riga importato"
    end
  end

  def save
    process!
    errors.none?
  end

  private

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
      numero_documento.split(" ")[1].split("/")[0].to_i
    end

 

end