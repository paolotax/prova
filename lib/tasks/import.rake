require 'csv'
require 'date'
require 'benchmark'

namespace :import do


  desc "cambia RELIGIONE elementari"
  task cambia_religione: :environment do

    Benchmark.bm do |x|
      x.report('agg. RELIGIONE') {
        NewAdozione.
          where(tipogradoscuola: "EE")
          .where(annocorso: ["2", "3", "5"], disciplina: ["RELIGIONE", "ADOZIONE ALTERNATIVA ART. 156 D.L. 297/94", "ADOZIONE ALTERNATIVA ART. 156 D.L. 297/94 "])
          .update_all(daacquist: "No")
      }
    end

  end

  desc "cambia SUPERIORI No-Nt"
  task cambia_superiori: :environment do

    Benchmark.bm do |x|
      x.report('agg. SUPERIORI') {
        ImportAdozione.where(TIPOGRADOSCUOLA: ["NO", "NT"]).update_all(TIPOGRADOSCUOLA: "SU")
      }
    end
  end

  desc "EDITORI da adozioni"
  task editori: :environment do

    include ActionView::Helpers
    include ApplicationHelper

    answer = HighLine.agree("Vuoi cancellare tutti i dati esistenti? (y/n)")
    if answer == true
      Editore.destroy_all
    end

    Benchmark.bm do |x|
      x.report('A') { @editori = ImportAdozione.order(:EDITORE).pluck(:EDITORE).uniq.map {|e| { editore: e } } }
      x.report('B') { Editore.import @editori, batch_size: 50 }
    end
  end

  desc "EDITORI CSV"
  task gruppi_editoriali: :environment do

    include ActionView::Helpers
    include ApplicationHelper

    answer = HighLine.agree("Vuoi cancellare tutti i dati esistenti? (y/n)")
    if answer == true
      Editore.destroy_all
    end

    counter = 0
    file_counter = 0

    csv_dir = File.join(Rails.root, '_miur/gruppi_editoriali.csv')

    #, "r:ISO-8859-1"
    Dir.glob(csv_dir).each do |file|
      items = []
      Benchmark.bm do |x|
        x.report("leggo  file #{file} #{file_counter}") do
          CSV.foreach(file, headers: true, col_sep: ',') do |row|
            items << row.to_h
            counter += 1
          end
        end
        x.report("scrivo file #{file} #{file_counter}") do
          Editore.import items, validate: false, on_duplicate_key_ignore: true, batch_size: 10000
          file_counter += 1
        end
      end
    end
  end

  desc "TIPI SCUOLE da adozioni"
  task tipi_scuole: :environment do

    include ActionView::Helpers
    include ApplicationHelper

    answer = HighLine.agree("Vuoi cancellare tutti i dati esistenti? (y/n)")
    if answer == true
      TipoScuola.destroy_all
    end

    sql = 'SELECT DISTINCT import_scuole."DESCRIZIONETIPOLOGIAGRADOISTRUZIONESCUOLA" as tipo,
                     SUBSTR(import_adozioni."TIPOGRADOSCUOLA", 1, 1) as grado
            FROM import_scuole
            INNER JOIN import_adozioni on import_scuole."CODICESCUOLA" = import_adozioni."CODICESCUOLA"
            GROUP BY tipo, grado
            ORDER BY grado, tipo'

    Benchmark.bm do |x|
      x.report("sql") do
        @tipi_scuole = ActiveRecord::Base.connection.execute(sql).map do |ts|
          { grado: ts['grado'], tipo: ts['tipo'] }
        end
      end
      # x.report('A') do
      #   @tipi_scuole = ImportScuola.joins(:import_adozioni)
      #             .order([:TIPOGRADOSCUOLA, :DESCRIZIONETIPOLOGIAGRADOISTRUZIONESCUOLA])
      #             .select(:TIPOGRADOSCUOLA, :DESCRIZIONETIPOLOGIAGRADOISTRUZIONESCUOLA)
      #             .distinct.map do |ts|
      #     { grado: ts.TIPOGRADOSCUOLA, tipo: ts.DESCRIZIONETIPOLOGIAGRADOISTRUZIONESCUOLA }
      #   end
      # end
      x.report('B') { TipoScuola.import @tipi_scuole, batch_size: 50 }
    end
  end

  desc "ZONE"
  task zone: :environment do

    include ActionView::Helpers
    include ApplicationHelper

    answer = HighLine.agree("Vuoi cancellare tutti i dati esistenti? (y/n)")
    if answer == true
      Zona.destroy_all
    end

    Benchmark.bm do |x|
      x.report('A') do
        @zona = ImportScuola.order([:AREAGEOGRAFICA, :REGIONE, :PROVINCIA, :DESCRIZIONECOMUNE])
                            .select(:AREAGEOGRAFICA, :REGIONE, :PROVINCIA, :DESCRIZIONECOMUNE, :CODICECOMUNESCUOLA)
                            .distinct.map do |z|
          { area_geografica: z.AREAGEOGRAFICA, regione: z.REGIONE, provincia: z.PROVINCIA, comune: z.DESCRIZIONECOMUNE, codice_comune: z.CODICECOMUNESCUOLA }
        end
      end
      x.report('B') { Zona.import @zona, batch_size: 50 }
    end
  end

  desc "ADOZIONI"
  task miur_adozioni: :environment do

    include ActionView::Helpers
    include ApplicationHelper

    answer = HighLine.agree("Vuoi cancellare tutti i dati esistenti? (y/n)")
    if answer == true
      ImportAdozione.delete_all
    end

    counter = 0
    file_counter = 0

    csv_dir = File.join(Rails.root, '_miur/adozioni/*.csv')
    tmp_dir = File.join(Rails.root, 'storage/tmp')
    #, "r:ISO-8859-1"


    Dir.glob(csv_dir).each do |file|
      file_size = File.size(file)
      if file_size > 30 * 1024 * 1024 # 30MB in bytes

        FileUtils.mkdir_p(tmp_dir) unless File.directory?(tmp_dir)
        split_files = []
        split_counter = 0

        Benchmark.bm do |x|
          x.report("splitto #{file.split('/').last}\n") do
            CSV.foreach(file, headers: true, col_sep: ',') do |row|
              split_files[split_counter] ||= []
              split_files[split_counter] << row.headers if split_files[split_counter].empty?
              split_files[split_counter] << row.to_h
              if split_files[split_counter].size >= 10000 # Split every 10,000 rows
                split_counter += 1
              end
            end
          end
        end

        # Senza salvataggio su file
        # Benchmark.bm do |x|
        #   x.report("importing split hash\n") do
        #     split_files.each_with_index do |split_data, index|
        #       puts split_data
        #       #ImportAdozione.import split_data[index], validate: false, on_duplicate_key_ignore: true
        #     end
        #   end
        # end

        # con salvataggio su file
        Benchmark.bm do |x|
          x.report("saving csv split files\n") do
            split_files.each_with_index do |split_data, index|
              split_file_path = "#{tmp_dir}/#{File.basename(file, '.csv')}_part#{index + 1}.csv"

              CSV.open(split_file_path, 'w', headers: true, col_sep: ',') do |csv|
                split_data.each do |row|
                  csv << row
                end
              end

              data = []
              CSV.foreach(split_file_path, headers: true, col_sep: ',') do |row|
                data << row.to_h
              end
              ImportAdozione.import data, validate: false, on_duplicate_key_ignore: true
              FileUtils.rm(split_file_path)
            end
          end
        end
      else
        items = []
        Benchmark.bm do |x|
          x.report("leggo #{file.split('/').last} #{file_counter}\n") do
            CSV.foreach(file, headers: true, col_sep: ',') do |row|
              items << row.to_h
              counter += 1
            end
          end
          x.report("scrivo #{file.split('/').last} #{file_counter}\n") do
            ImportAdozione.import items, validate: false, on_duplicate_key_ignore: true
            file_counter += 1
          end
        end
      end
    end
  end

  desc "SCUOLE"
  task miur_scuole: :environment do

    include ActionView::Helpers
    include ApplicationHelper

    answer = HighLine.agree("Vuoi cancellare tutti i dati esistenti? (y/n)")
    if answer == true
      ImportScuola.destroy_all
    end

    counter = 0
    file_counter = 0

    csv_dir = File.join(Rails.root, '_miur/scuole/*.csv')

    Dir.glob(csv_dir).each do |file|
      items = []
      Benchmark.bm do |x|
        x.report("leggo  file scuole #{file.split('/').last} - #{file_counter}") do
          CSV.foreach(file, headers: true, col_sep: ',') do |row|
            items << row.to_h
            counter += 1
          end
        end
        x.report("scrivo file scuole  #{file.split('/').last} - #{file_counter}") do
          ImportScuola.import items, validate: false, on_duplicate_key_ignore: true, batch_size: 10000
          file_counter += 1
        end
      end
    end

  end

  desc "csv GAIA"
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

  desc "xml ARUBA"
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






  desc "Importa nuove ADOZIONI 2025/6"
  task new_adozioni: :environment do

    include ActionView::Helpers
    include ApplicationHelper

    answer = HighLine.agree("ADOZIONI 2025/6 Vuoi cancellare tutti i dati esistenti? (y/n)")
    if answer == true
      NewAdozione.delete_all
    end

    map_adozioni = {
      "ANNOCORSO" => "annocorso",
      "AUTORI" => "autori",
      "CODICEISBN" => "codiceisbn",
      "CODICESCUOLA" => "codicescuola",
      "COMBINAZIONE" => "combinazione",
      "CONSIGLIATO" => "consigliato",
      "DAACQUIST" => "daacquist",
      "DISCIPLINA" => "disciplina",
      "EDITORE" => "editore",
      "NUOVAADOZ" => "nuovaadoz",
      "PREZZO" => "prezzo",
      "SEZIONEANNO" => "sezioneanno",
      "SOTTOTITOLO" => "sottotitolo",
      "TIPOGRADOSCUOLA" => "tipogradoscuola",
      "TITOLO" => "titolo",
      "VOLUME" => "volume",
    }

    csv_dir = Rails.root.join('tmp', '_miur', 'adozioni', '*.csv')

    Dir.glob(csv_dir).each do |file|
      import_csv(file, NewAdozione, map_adozioni)
    end

    puts "Totale: #{NewAdozione.count} NewAdozioni inserite"
  end

  desc "NewScuole SCUOLE 2024"
  task new_scuole: :environment do

    include ActionView::Helpers
    include ApplicationHelper

    answer = HighLine.agree("Vuoi cancellare tutti i dati esistenti? (y/n)")
    if answer == true
      NewScuola.delete_all
    end

    csv_dir = Rails.root.join('tmp', '_miur', 'scuole', '*.csv')

    map_scuole = {
      "ANNOSCOLASTICO" => "anno_scolastico",
      "AREAGEOGRAFICA" => "area_geografica",
      "REGIONE" => "regione",
      "PROVINCIA" => "provincia",
      "CODICEISTITUTORIFERIMENTO" => "codice_istituto_riferimento",
      "DENOMINAZIONEISTITUTORIFERIMENTO" => "denominazione_istituto_riferimento",
      "CODICESCUOLA" => "codice_scuola",
      "DENOMINAZIONESCUOLA" => "denominazione",
      "INDIRIZZOSCUOLA" => "indirizzo",
      "CAPSCUOLA" => "cap",
      "CODICECOMUNESCUOLA" => "codice_comune",
      "DESCRIZIONECOMUNE" => "comune",
      "DESCRIZIONECARATTERISTICASCUOLA" => "descrizione_caratteristica",
      "DESCRIZIONETIPOLOGIAGRADOISTRUZIONESCUOLA" => "tipo_scuola",
      "INDICAZIONESEDEDIRETTIVO" => "indicazione_sede_direttivo",
      "INDICAZIONESEDEOMNICOMPRENSIVO" => "indicazione_sede_omnicomprensivo",
      "INDIRIZZOEMAILSCUOLA" => "email",
      "INDIRIZZOPECSCUOLA" => "pec",
      "SITOWEBSCUOLA" => "sito_web",
      "SEDESCOLASTICA" => "sede_scolastica"
    }

    Dir.glob(csv_dir).each do |file|
      import_csv(file, NewScuola, map_scuole)
    end

    puts "Totale NewScuola: #{NewScuola.count}"

    sql = 'UPDATE new_scuole SET import_scuola_id = import_scuole.id FROM import_scuole WHERE import_scuole."CODICESCUOLA" = new_scuole.codice_scuola'
    ActiveRecord::Base.connection.execute(sql)

    puts "Totale NewScuola con import_scuola_id: #{NewScuola.where.not(import_scuola_id: nil).count}"


  end







  desc "Splitta file adozioni"
  task splitta_adozioni: :environment do
    csv_dir = File.join(Rails.root, '_miur/adozioni/*.csv')
    Dir.glob(csv_dir).each do |file|
      #puts "name: #{file} size: #{File.size(file)} chunks: #{File.size(file) / (3 * 1024 * 1024)}"
      if File.size(file) > 5 * 1024 * 1024 # 7MB in bytes
        split_csv(file, File.size(file) / (3 * 1024 * 1024))
        FileUtils.rm(file)
      end
    end
  end



  task import_2024: :environment do

    NewAdozione.find_each(batch_size: 100_000) do |new_adozione|
      ImportAdozione.create!(
        anno_scolastico: '202425',

        ANNOCORSO: new_adozione.annocorso,
        AUTORI: new_adozione.autori,
        CODICEISBN: new_adozione.codiceisbn,
        CODICESCUOLA: new_adozione.codicescuola,
        COMBINAZIONE: new_adozione.combinazione,
        CONSIGLIATO: new_adozione.consigliato,
        DAACQUIST: new_adozione.daacquist,
        DISCIPLINA: new_adozione.disciplina,
        EDITORE: new_adozione.editore,
        NUOVAADOZ: new_adozione.nuovaadoz,
        PREZZO: new_adozione.prezzo,
        SEZIONEANNO: new_adozione.sezioneanno,
        SOTTOTITOLO: new_adozione.sottotitolo,
        TIPOGRADOSCUOLA: new_adozione.tipogradoscuola,
        TITOLO: new_adozione.titolo,
        VOLUME: new_adozione.volume
      )
      puts new_adozione.id
    end
  end




  private

    def split_csv(original, file_count)
      header_lines = 1
      lines = Integer(`cat #{original} | wc -l`) - header_lines
      lines_per_file = (lines / file_count.to_f).ceil + header_lines
      header = `head -n #{header_lines} #{original}`

      start = header_lines
      file_count.times.map do |i|
        finish = start + lines_per_file
        file = "#{original}-#{i}.csv"

        File.write(file, header)
        sh "tail -n #{lines - start} #{original} | head -n #{lines_per_file} >> #{file}"

        start = finish
        file
      end
    end

    def self.import_csv(file, model, mappings, options = { col_sep: ',', headers: true, encoding: 'UTF-8' })

      items = []
      counter = 0
      file_counter = 0

      Benchmark.bm do |x|
        x.report("leggo #{model} #{file.split('/').last}") do
          CSV.foreach(file, headers: options[:headers], col_sep: options[:col_sep], encoding: options[:encoding]) do |row|
            if mappings.present?
              row = row.to_h.transform_keys(mappings)
              items << row
            else
              items << row.to_h
            end
            counter += 1
          end
        end
        x.report("importo #{model}  #{file.split('/').last}") do
          model.import items, validate: false, on_duplicate_key_ignore: true
          file_counter += 1
        end
      end

      puts "righe inserite #{counter} da #{file_counter} file/s"
    end





end