# frozen_string_literal: true

module Imports
  class DocumentiProcessor < BaseProcessor
    attr_accessor :documento_id
    attr_reader :documento

    def initialize(file, user, documento_id: nil, **kwargs)
      super(file, user, **kwargs)
      @documento_id = documento_id
    end

    protected

    def process_file
      if xml_file?
        process_xml
      else
        process_excel
      end
    end

    private

    def xml_file?
      file_path.to_s.end_with?('.xml')
    end

    def process_excel
      documento = @user.documenti.find(@documento_id)
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
      cliente = @user.clienti.find_by(partita_iva: partita_iva)

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

      if @user.documenti.find_by(numero_documento: numero_documento, causale_id: causale.id, clientable_id: cliente.id)
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

        libro = @user.libri.find_by(codice_isbn: codice_valore)

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

    def find_or_create_libro(row, codice, line)
      libro = @user.libri.find_by(codice_isbn: codice)
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
