require 'csv'
require 'date'


namespace :import do
  
  desc "import righe from csv gaia"  
  task gaia: :environment do
        
    answer = HighLine.agree("Vuoi cancellare tutti i dati esistenti? (y/n)")
    
    if answer == true
      puts 'wait....'
      Import.destroy_all
    end

    puts 'wait........'

    counter = 0
    file_counter = 0
    
    csv_dir = File.join(Rails.root, '_csv/*.csv')
    
    Dir.glob(csv_dir).each do |file|
      
      CSV.foreach(file, "r:ISO-8859-1", headers: true, col_sep: ';') do |row|
        
        if row["Data"].nil?
          my_date = nil
          puts "la riga #{counter} ha una data errata. Documento-#{row["NumeroDocumento"]} file: #{file}"
        else
          my_date = Date.strptime(row["Data"], "%d/%m/%y")
        end
        
        if row["Prezzo Unit."].nil?
          prezzo = row["PrezzoCopertina"]
        else
          prezzo = row["Prezzo Unit."]
        end               
        
        import = Import.create(
          fornitore:        row["Fornitore"],
          tipo_documento:   row["TipoDocumento"],
          numero_documento: row["NumeroDocumento"],  
          data_documento:   my_date,
          
          totale_documento:   row["ImportoTotale"],
          
          
          riga:             row["Riga"],
          codice_articolo:  row["Cod.articolo"],
          descrizione:      row["Descrizione"],
          
          prezzo_unitario:  prezzo,
          quantita:         row["Quantita"],
          
          importo_netto:    row["TotNetto"],
          sconto:           row["Sconti"],
          iva:              row["Iva"]
        )
        
        counter += 1 if import.persisted?
      end
      
      file_counter += 1
    end
    
    puts "righe inserite #{counter} da #{file_counter} file/s"
    
  end


  "import righe from xml aruba"  
  task aruba: :environment do
     
    answer = HighLine.agree("Vuoi cancellare tutti i dati esistenti? (y/n)")
    if answer == true
      puts 'wait....'
      Import.destroy_all
    end
    puts 'wait........'

    # # Specifica il percorso in cui salvare il file CSV risultante
    # csv_file_path = 'import_aruba/output.csv'
    # Inizializza un array per contenere tutti i dati XML
    # all_xml_data = []

    counter = 0
    file_counter = 0
    
    # Specifica la directory contenente i file XML
    xml_dir = File.join('_xml/*.xml') 
    
    # Loop attraverso i file XML nella directory
    Dir.glob(xml_dir).each do |file|
      
      doc = Nokogiri::XML(File.open(file))
      
      # Specifica il percorso agli elementi XML che vuoi estrarre
      righe_path = '//DettaglioLinee'
      
      # Esegui un loop sugli elementi XML che corrispondono al percorso specificato
      doc.xpath(righe_path).each do |element|
        
        quantita = element.xpath("./Quantita").text       
        if quantita == ''  
          quantita = '0' 
        end
        
        import = Import.create(
          fornitore:        doc.xpath('//CedentePrestatore/DatiAnagrafici/Anagrafica/Denominazione').text,
          
          tipo_documento:   doc.xpath('//DatiGeneraliDocumento/TipoDocumento').text,
          numero_documento: doc.xpath('//DatiGeneraliDocumento/Numero').text,  
          data_documento:   doc.xpath('//DatiGeneraliDocumento/Data').text,
          
          totale_documento:   doc.xpath('//DatiGeneraliDocumento/ImportoTotaleDocumento').text,
          
          
          riga:             element.xpath("./NumeroLinea"),
          codice_articolo:  element.xpath("./CodiceArticolo/CodiceValore").text,
          descrizione:      element.xpath("./Descrizione").text,
          
          prezzo_unitario:  element.xpath("./PrezzoUnitario").text,
          quantita:         quantita,
          
          importo_netto:    element.xpath("./PrezzoTotale").text,
          sconto:           element.xpath("./ScontoMaggiorazione/Percentuale").text,
          iva:              74
        )

        counter += 1 if import.persisted?

        # item = {
        
        #   'tipo_documento' => doc.xpath('//DatiGeneraliDocumento/TipoDocumento').text,
        #   'data_documento'          => doc.xpath('//DatiGeneraliDocumento/Data').text,
        #   'numero_documento'        => doc.xpath('//DatiGeneraliDocumento/Numero').text,
        #   'totale_documento' => doc.xpath('//DatiGeneraliDocumento/ImportoTotaleDocumento').text,
          
        #   'Cliente' =>    doc.xpath('//CessionarioCommittente/DatiAnagrafici/Anagrafica/Denominazione').text,
        #   'Comune'  =>    doc.xpath('//CessionarioCommittente/Sede/Comune').text,
        #   'Provincia'  => doc.xpath('//CessionarioCommittente/Sede/Provincia').text,
        #   'IvaCliente' => doc.xpath('//CessionarioCommittente/DatiAnagrafici/IdFiscaleIVA/IdCodice').text,
          
        #   'riga'  => element.xpath("./NumeroLinea").text,
        #   'CodiceTipo'   => element.xpath("./CodiceArticolo/CodiceTipo").text,
        #   'codice_articolo' => element.xpath("./CodiceArticolo/CodiceValore").text,
          
        #   'descrizione' => element.xpath("./Descrizione").text,
        #   'quantita'    => quantita,
          
        #   'UnitaMisura'    => element.xpath("./UnitaMisura").text,
        #   'prezzo_unitario' => element.xpath("./PrezzoUnitario").text,
        #   'sconto'         => element.xpath("./ScontoMaggiorazione/Percentuale").text,
        #   'importo_netto'   => element.xpath("./PrezzoTotale").text,
        #   'fornitore' =>    doc.xpath('//CedentePrestatore/DatiAnagrafici/Anagrafica/Denominazione').text,      
        #   'iva_fornitore'  =>    doc.xpath('//CedentePrestatore/DatiAnagrafici/IdFiscaleIVA/IdCodice').text
          
        # }
        # all_xml_data << item
      end

      file_counter += 1
    end

    puts "righe inserite #{counter} da #{file_counter} file/s"

    
    # # Apri un file CSV in modalità scrittura
    # CSV.open(csv_file_path, 'w') do |csv|
    #   # Scrivi l'intestazione del CSV
    #   csv << ['NomeFornitore', 'IvaFornitore', 'TipoDocumento', 'Data', 'Numero', 'ImportoTotaleDocumento', 'Cliente', 'Comune', 'Provincia', 'IvaCliente', 'NumeroLinea', 'CodiceTipo', 'CodiceValore','Descrizione', 'Quantita', 'UnitaMisura', 'PrezzoUnitario', 'Sconto', 'PrezzoTotale'] 
      
    #   # Scrivi i dati XML convertiti come righe CSV
    #   all_xml_data.each do |item|
    #     csv << item.values
    #   end
    # end
    # puts "Conversione di tutti i file XML in un unico file CSV completata. #{all_xml_data.count} righe #{all_xml_data}" 
  end
  
  
end