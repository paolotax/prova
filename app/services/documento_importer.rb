class DocumentoImporter

  include ActiveModel::Model
  attr_accessor :file, :imported_count, :updated_count, :errors_count, :import_method

  def initialize(attributes = {})
    super
    @imported_count = 0
    @updated_count = 0
    @errors_count = 0
  end

  def process!
  end

  def import_xml
       
    # Specifica la directory contenente i file XML
    xml_dir = File.join('_xml/*.xml') 
    
    # Loop attraverso i file XML nella directory
    Dir.glob(xml_dir).each do |file|
      
      doc = Nokogiri::XML(File.open(file))

      cliente_id = Current.user.clienti.find_by(partita_iva: doc.xpath('//CessionarioCommittente/DatiAnagrafici/IdFiscaleIVA/IdCodice').text)&.id
      puts "cliente id #{cliente_id}"
      
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

          puts libro_id

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



  def flash_message
    if @imported_count > 0 || @updated_count > 0 || @errors_count > 0
      pluralize(@imported_count, 'libro importato', 'libri importati') + " e " + 
      pluralize(@updated_count, 'libro aggiornato', 'libri aggiornati') + " e " + 
      pluralize(@errors_count, 'libro errato', 'libri errati') + 
      " " + errors.full_messages.join(", ").html_safe
    else
      "Nessun libro importato"
    end
  end

  def save
    process!
    #errors.none?
  end

  private

    def assign_from_row(row)
 
      codice_isbn = row[:codice_isbn] || row["codice_isbn"]
      user_id = Current.user.id
      libro = Libro.where(codice_isbn: codice_isbn, user_id: user_id).first_or_initialize
      unless libro.new_record?
        if row[:titolo] then row.delete(:titolo) end
        if row["titolo"] then row.delete("titolo") end
      end
      libro.assign_attributes row.to_hash
      libro
    end


    def parse_numero_documento(numero_documento)
      numero_documento.split(" ")[1].split("/")[0].to_i
    end

 

end