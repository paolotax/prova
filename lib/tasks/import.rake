require 'csv'
require 'date'

namespace :import do


  desc "cammbia classi e religione da acquistare"
  task cambia_classi_e_religione: :environment do

    start = Time.now
    righe_count = ImportAdozione.elementari.di_reggio.where(ANNOCORSO: ["2", "3", "5"], DISCIPLINA: "RELIGIONE").update(DAACQUIST: "No").count
    puts "adozioni di religione aggiornate in #{(Time.now - start).to_i} secondi"

    start = Time.now
    ImportAdozione.elementari.di_reggio.where(ANNOCORSO: "1").update(ANNOCORSO: "1 - prima")
    ImportAdozione.elementari.di_reggio.where(ANNOCORSO: "2").update(ANNOCORSO: "2 - seconda")
    ImportAdozione.elementari.di_reggio.where(ANNOCORSO: "3").update(ANNOCORSO: "3 - terza")
    ImportAdozione.elementari.di_reggio.where(ANNOCORSO: "4").update(ANNOCORSO: "4 - quarta")
    ImportAdozione.elementari.di_reggio.where(ANNOCORSO: "5").update(ANNOCORSO: "5 - quinta")
    puts "classi aggiornate in #{(Time.now - start).to_i} secondi"
  end
  
  desc "init user"
  task init: :environment do  

    nome = 'Paolo Tassinari'
    partita_iva = '04155820378'

    user = User.create(name: nome, partita_iva: partita_iva)
    
    puts "user #{user.name} created"
  end 

  desc "import adozioni from miur" 
  task miur_adozioni: :environment do
    
    include ActionView::Helpers
    include ApplicationHelper

    answer = HighLine.agree("Vuoi cancellare tutti i dati esistenti? (y/n)")
    
    if answer == true
      start_destroy = Time.now
      puts 'wait....'
      ImportAdozione.delete_all
      puts "#{ tempo_trascorso(start_destroy) } - end destroy_all"
    end
    
    start = Time.now
    start_reading = Time.now
    puts "- start reading.  wait........"

    counter = 0
    file_counter = 0
    
    csv_dir = File.join(Rails.root, '_miur/adozioni/*.csv')
    
    items = []

    #    , "r:ISO-8859-1"
    Dir.glob(csv_dir).each do |file|
      CSV.foreach(file, headers: true, col_sep: ',') do |row|
        items << row.to_h if row["TIPOGRADOSCUOLA"] == "MM"
        counter += 1 
      end      
      file_counter += 1
    end

    puts "#{ tempo_trascorso(start_reading) } - started importing.  wait........"

    ImportAdozione.import items, validate: false, on_duplicate_key_update: true
    
    fine = Time.now
    
    puts "#{ tempo_trascorso(start)} - end importing"
    puts "tempo totale #{ tempo_trascorso(start, fine) }"
    puts "righe inserite #{items.size} da #{file_counter} file/s"

  end

  desc "import scuole from miur"
  task miur_scuole: :environment do

    include ActionView::Helpers
    include ApplicationHelper
      
      answer = HighLine.agree("Vuoi cancellare tutti i dati esistenti? (y/n)")
      
      if answer == true
        start_destroy = Time.now
        puts 'wait....'
        ImportScuola.delete_all
        puts "#{ tempo_trascorso(start_destroy) } - end destroy_all"
      end
      
      start = Time.now
      start_reading = Time.now
      puts "- start reading.  wait........"

      counter = 0
      file_counter = 0
      
      csv_dir = File.join(Rails.root, '_miur/scuole/*.csv')
      
      items = []

      #    , "r:ISO-8859-1"
      Dir.glob(csv_dir).each do |file|
        CSV.foreach(file, headers: true, col_sep: ',') do |row|
 
          # campi mancanti da aggiungere
          # ["SEDESCOLASTICA", "CODICEISTITUTORIFERIMENTO", "DENOMINAZIONEISTITUTORIFERIMENTO", 
          #  "DESCRIZIONECARATTERISTICASCUOLA", "INDICAZIONESEDEDIRETTIVO", "INDICAZIONESEDEOMNICOMPRENSIVO"]

          row.push({"CODICEISTITUTORIFERIMENTO" => ""}) if !row["CODICEISTITUTORIFERIMENTO"].present?
          row.push({"DENOMINAZIONEISTITUTORIFERIMENTO" => ""}) if !row["DENOMINAZIONEISTITUTORIFERIMENTO"].present?
          row.push({"DESCRIZIONECARATTERISTICASCUOLA" => ""}) if !row["DESCRIZIONECARATTERISTICASCUOLA"].present?
          row.push({"INDICAZIONESEDEDIRETTIVO" => ""}) if !row["INDICAZIONESEDEDIRETTIVO"].present?
          row.push({"INDICAZIONESEDEOMNICOMPRENSIVO" => ""} )if !row["INDICAZIONESEDEOMNICOMPRENSIVO"].present?
          
          
          if !row["SEDESCOLASTICA"].present?
            row.push({"SEDESCOLASTICA" => ""})
            # puts row.to_h
          end
          
          items << row.to_h
          counter += 1 
        end      
        file_counter += 1
      end

      puts "#{ tempo_trascorso(start_reading) } - started importing.  wait........"

      ImportScuola.import items, validate: false, on_duplicate_key_update: true
      
      fine = Time.now
      
      puts "#{ tempo_trascorso(start)} - end importing"
      puts "tempo totale #{ tempo_trascorso(start, fine) }"
      puts "righe inserite #{items.size} da #{file_counter} file/s"
    
  end

  desc "import righe from csv gaia"  
  task gaia: :environment do
        
    answer = HighLine.agree("Vuoi cancellare tutti i dati esistenti? (y/n)")
    
    if answer == true
      puts 'wait....'
      Import.delete_all
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

        if row["Fornitore"] == "Gaia" then
          iva_fornitore = '01899780181'
        else
          iva_fornitore = '12472610968'
        end
        
        if row["Prezzo Unit."].nil?
          prezzo = row["PrezzoCopertina"]
        else
          prezzo = row["Prezzo Unit."]
        end               
        
        import = Import.create(
          fornitore:        row["Fornitore"],
          iva_fornitore:    iva_fornitore,
          cliente:          'Paolo Tassinari',
          iva_cliente:      '04155820378',

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


  desc "import righe from xml aruba"  
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
          iva_fornitore:    doc.xpath('//CedentePrestatore/DatiAnagrafici/IdFiscaleIVA/IdCodice').text,

          cliente:          doc.xpath('//CessionarioCommittente/DatiAnagrafici/Anagrafica/Denominazione').text,
          iva_cliente:      doc.xpath('//CessionarioCommittente/DatiAnagrafici/IdFiscaleIVA/IdCodice').text,

          tipo_documento:   doc.xpath('//DatiGeneraliDocumento/TipoDocumento').text,
          numero_documento: doc.xpath('//DatiGeneraliDocumento/Numero').text,  
          data_documento:   doc.xpath('//DatiGeneraliDocumento/Data').text,
          
          totale_documento:   doc.xpath('//DatiGeneraliDocumento/ImportoTotaleDocumento').text,
          
          
          riga:             element.xpath("./NumeroLinea").text,
          codice_articolo:  element.xpath("./CodiceArticolo/CodiceValore").text,
          descrizione:      element.xpath("./Descrizione").text,
          
          prezzo_unitario:  element.xpath("./PrezzoUnitario").text,
          quantita:         quantita,
          
          importo_netto:    element.xpath("./PrezzoTotale").text,
          sconto:           element.xpath("./ScontoMaggiorazione/Percentuale").text,
          
          iva:              element.xpath("./AliquotaIVA").text
        )

        counter += 1 if import.persisted?
      end

      file_counter += 1
    end

    puts "righe inserite #{counter} da #{file_counter} file/s"

  end
  
  
end