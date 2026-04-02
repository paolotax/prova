# frozen_string_literal: true

module Imports
  class DocumentiProcessor < BaseProcessor
    attr_reader :documento

    protected

    def process_file
      case detected_format
      when "xml"
        process_xml
      when "pdf"
        process_ndc_pdf
      else
        process_excel
      end
    end

    private

    def detected_format
      return @metadata["format"] if @metadata["format"].present?

      case file_path.to_s
      when /\.xml\z/i then "xml"
      when /\.pdf\z/i then "pdf"
      else "excel"
      end
    end

    def process_excel
      documento = @account.documenti.find(@metadata["documento_id"])
      righe_con_errori = []

      parse_excel do |row, line|
        codice = row[:codice_isbn] || row[:ean] || row[:isbn]

        if codice.blank?
          add_error("Codice ISBN mancante", line: line)
          next
        end

        libro = find_or_create_libro(row, codice, line)
        next unless libro

        quantita = row[:quantità] || row[:quantita] || row[:qta] || 1
        prezzo_cents = calculate_prezzo(row, libro)
        sconto = row[:sconto].present? ? row[:sconto].to_f : 0.0

        documento_riga = documento.documento_righe.build
        riga = documento_riga.build_riga(
          libro: libro,
          sconto: sconto,
          quantita: quantita,
          prezzo_cents: prezzo_cents
        )

        if documento_riga.save
          @imported_count += 1
          @documento = documento
        else
          add_error(riga.errors.full_messages.join(", "), line: line)
        end
      end

      documento.reload.ricalcola_totali! if documento.present?
    end

    def process_xml
      doc = Nokogiri::XML(File.open(file_path))

      unless doc
        add_error("Errore nel file XML")
        return
      end

      partita_iva = doc.xpath('//CessionarioCommittente/DatiAnagrafici/IdFiscaleIVA/IdCodice').text
      cliente = @account.clienti.find_by(partita_iva: partita_iva)

      unless cliente
        add_error("Cliente non trovato con P.IVA: #{partita_iva}")
        return
      end

      tipo_documento = doc.xpath('//DatiGeneraliDocumento/TipoDocumento').text
      causale = Causale.find_by(causale: tipo_documento)

      unless causale
        add_error("Causale '#{tipo_documento}' non trovata nel sistema")
        return
      end

      numero_documento = parse_numero_documento(doc.xpath('//DatiGeneraliDocumento/Numero').text)

      unless numero_documento.present?
        add_error("Numero documento non trovato nel file XML")
        return
      end

      if @account.documenti.find_by(numero_documento: numero_documento, causale_id: causale.id, clientable_id: cliente.id)
        add_error("Documento n. #{numero_documento} già presente per questo cliente")
        return
      end

      documento = @user.documenti.create(
        account: @account,
        clientable_type: "Cliente",
        clientable_id: cliente.id,
        causale_id: causale.id,
        numero_documento: numero_documento,
        data_documento: Date.parse(doc.xpath('//DatiGeneraliDocumento/Data').text)
      )

      righe_saltate = []
      righe_trovate = 0

      doc.xpath('//DettaglioLinee').each do |element|
        quantita = element.xpath("./Quantita").text
        quantita = '0' if quantita.blank?

        posizione = element.xpath("./NumeroLinea").text
        codice_articoli = element.xpath("./CodiceArticolo")

        codice_valore = if codice_articoli.size > 1
          codice_articoli[0].xpath("./CodiceValore").text
        else
          codice_articoli.xpath("./CodiceValore").text
        end

        libro = @account.libri.find_by(codice_isbn: codice_valore)

        if libro
          documento.documento_righe.build(posizione: posizione).build_riga(
            libro_id: libro.id,
            prezzo_cents: (element.xpath("./PrezzoUnitario").text.to_f * 100).to_i,
            quantita: quantita,
            sconto: element.xpath("./ScontoMaggiorazione/Percentuale").text.presence || 0.0
          )
          righe_trovate += 1
        else
          descrizione = element.xpath("./Descrizione").text
          righe_saltate << "Riga #{posizione}: #{codice_valore} - #{descrizione}"
        end
      end

      unless documento.save
        add_error("Errore nel salvataggio del documento: #{documento.errors.full_messages.join(', ')}")
        return
      end

      @imported_count = righe_trovate

      @documento = documento
      documento.reload.ricalcola_totali!

      if righe_saltate.any?
        add_error("#{righe_saltate.count} righe non importate (articoli non trovati)")
        righe_saltate.first(5).each { |r| add_error(r) }
        add_error("... e altre #{righe_saltate.count - 5} righe") if righe_saltate.count > 5
      end
    end

    def process_ndc_pdf
      reader = PDF::Reader.new(file_path)
      text = reader.pages.map(&:text).join("\n")

      # Estrai numero e data dalla riga "NOTA DI CONSEGNA N. XXXXX del DD-MM-YYYY"
      match = text.match(/NOTA DI CONSEGNA N\.\s*(\d+)\s*del\s*(\d{2}-\d{2}-\d{4})/)
      unless match
        add_error("Formato PDF non riconosciuto: numero/data non trovati")
        return
      end

      numero_documento = match[1].sub(/\A\d{4}/, '').to_i
      data_documento = Date.parse(match[2])

      # Cerca causale DDT Fornitore (carico merce)
      causale = Causale.find_by(causale: "DDT Fornitore")
      unless causale
        add_error("Causale 'DDT Fornitore' non trovata")
        return
      end

      # Cerca il fornitore dalla P.IVA nel PDF
      piva_match = text.match(/P\.I\.\s*IT\s*(\d{11})/)
      partita_iva = piva_match ? piva_match[1] : nil

      cliente = @account.clienti.find_by(partita_iva: partita_iva) if partita_iva
      unless cliente
        add_error("Fornitore non trovato con P.IVA: #{partita_iva || 'non trovata'}")
        return
      end

      # Verifica duplicati
      if @account.documenti.find_by(numero_documento: numero_documento, causale_id: causale.id, clientable_id: cliente.id)
        add_error("Documento NdC n. #{numero_documento} già presente")
        return
      end

      # Crea il documento
      documento = @user.documenti.create(
        account: @account,
        clientable_type: "Cliente",
        clientable_id: cliente.id,
        causale_id: causale.id,
        numero_documento: numero_documento,
        data_documento: data_documento
      )

      unless documento.persisted?
        add_error("Errore creazione documento: #{documento.errors.full_messages.join(', ')}")
        return
      end

      # Parsa le righe dal testo PDF
      righe_saltate = []
      righe_create = []
      posizione = 0

      text.each_line do |line|
        riga_match = line.match(/^\s*(\d+\w+)\s+(.+?)\s{2,}(\d+)\s+([\d]+,\d{2})\s+.*?(97[89]\d{10})\s*$/)
        next unless riga_match

        descrizione = riga_match[2].strip
        quantita = riga_match[3].to_i
        prezzo = riga_match[4].gsub(",", ".").to_f
        ean = riga_match[5].strip

        next if quantita == 0

        posizione += 1

        # Cerca libro per EAN, se non esiste lo crea
        libro = @account.libri.find_by(codice_isbn: ean)
        libro_creato = false

        unless libro
          categoria = Categoria.resolve(nil, user: @user, account: @account)
          libro = @user.libri.create(
            account: @account,
            codice_isbn: ean,
            titolo: descrizione,
            categoria: categoria,
            prezzo_in_cents: (prezzo * 100).to_i
          )
          libro_creato = true
        end

        if libro.persisted?
          riga = Riga.create(
            libro_id: libro.id,
            prezzo_cents: (prezzo * 100).to_i,
            quantita: quantita,
            sconto: 0.0
          )
          if riga.persisted?
            documento.documento_righe.create(posizione: posizione, riga: riga)
            @imported_count += 1
            righe_create << "#{ean} - #{descrizione}" if libro_creato
          else
            righe_saltate << "#{ean} - #{descrizione} (errore riga: #{riga.errors.full_messages.join(', ')})"
          end
        else
          righe_saltate << "#{ean} - #{descrizione} (qta: #{quantita})"
        end
      end

      @documento = documento
      documento.reload.ricalcola_totali!

      if righe_create.any?
        add_error("#{righe_create.count} libri creati automaticamente")
        righe_create.first(5).each { |r| add_error(r) }
        add_error("... e altri #{righe_create.count - 5} libri creati") if righe_create.count > 5
      end

      if righe_saltate.any?
        add_error("#{righe_saltate.count} righe non importate (errore creazione libro)")
        righe_saltate.each { |r| add_error(r) }
      end
    end

    def find_or_create_libro(row, codice, line)
      libro = @account.libri.find_by(codice_isbn: codice)
      return libro if libro

      titolo = row[:titolo] || row[:descrizione] || "Libro #{codice}"
      categoria = Categoria.resolve(nil, user: @user, account: @account)

      libro = @user.libri.create(
        account: @account,
        codice_isbn: codice,
        titolo: titolo,
        categoria: categoria,
        prezzo_in_cents: row[:prezzo].present? ? (row[:prezzo].to_f * 100).to_i : 0
      )

      unless libro.persisted?
        add_error("Impossibile creare libro - #{libro.errors.full_messages.join(', ')}", line: line)
        return nil
      end

      libro
    end

    def calculate_prezzo(row, libro)
      if row[:prezzo].present?
        (row[:prezzo].to_f * 100).to_i
      elsif libro&.prezzo_in_cents.present?
        libro.prezzo_in_cents
      else
        0
      end
    end

    def parse_numero_documento(numero_documento)
      numero_documento.gsub(/\D/, '')
    end
  end
end
