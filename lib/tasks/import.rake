require 'csv'
require 'date'

namespace :import do

    desc "import righe from csv"
   
    task righe: :environment do
        
        puts 'wait....'

        Import.destroy_all 

        options = {  }
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

end