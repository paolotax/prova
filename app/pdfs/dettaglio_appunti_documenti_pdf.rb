# encoding: utf-8
require "prawn/measurement_extensions"

class DettaglioAppuntiDocumentiPdf < Prawn::Document
  
  include LayoutPdf
  
  def initialize(appunti_dettagliati, documenti_dettagliati, giorno, view, riassunto_titoli = {})
    super(:page_size => "A4", 
          :page_layout => :portrait,
          :margin => [1.cm, 15.mm],
          :info => {
              :Title => "Dettaglio Appunti e Documenti",
              :Author => "todo-propa",
              :Subject => "Dettaglio appunti e documenti pendenti per tappa",
              :Keywords => "appunti documenti tappe dettaglio todo-propa",
              :Creator => "todo-propa",
              :Producer => "Prawn",
              :CreationDate => Time.now
          }
    )

    font_families.update(
      "DejaVuSans" => {
        normal: Rails.root.join("app/assets/fonts/DejaVuSans.ttf"),
        bold: Rails.root.join("app/assets/fonts/DejaVuSans-Bold.ttf"),
        italic: Rails.root.join("app/assets/fonts/DejaVuSans-Oblique.ttf")
      }
    )
    
    # Imposta il font di default
    font "DejaVuSans"
    
    @appunti_dettagliati = appunti_dettagliati
    @documenti_dettagliati = documenti_dettagliati
    @giorno = giorno
    @view = view
    @riassunto_titoli = riassunto_titoli

    generate_report
  end

  private

  def generate_report
    intestazione
    
    move_down 30
    
    # Titolo del report
    text "DETTAGLIO APPUNTI E DOCUMENTI PENDENTI", 
         size: 18, 
         style: :bold, 
         align: :center
    
    move_down 10
    
    text "Data: #{I18n.l(@giorno, format: :long, locale: :it)}", 
         size: 12, 
         align: :center
    
    move_down 20
    
    # Statistiche generali
    text "Totale appunti pendenti: #{@appunti_dettagliati.count}", size: 12, style: :bold
    text "Totale documenti pendenti: #{@documenti_dettagliati.count}", size: 12, style: :bold
    
    move_down 20
    
    # Sezione Appunti
    if @appunti_dettagliati.any?
      generate_appunti_section
      
      # Aggiungi una nuova pagina se ci sono anche documenti e non c'è spazio
      if @documenti_dettagliati.any? && cursor < 200
        start_new_page
        intestazione
        move_down 30
      else
        move_down 30
      end
    end
    
    # Sezione Documenti
    if @documenti_dettagliati.any?
      generate_documenti_section
      
      # Aggiungi tabella riassunto titoli se ci sono documenti da consegnare
      if @riassunto_titoli.any?
        move_down 30
        generate_riassunto_titoli_section
      end
    end
    
    # Se non ci sono né appunti né documenti
    if @appunti_dettagliati.empty? && @documenti_dettagliati.empty?
      text "Nessun appunto o documento pendente per le tappe di oggi.", 
           size: 14, 
           align: :center, 
           style: :italic
    end
  end

  def generate_appunti_section
    text "APPUNTI PENDENTI", 
         size: 16, 
         style: :bold, 
         color: "0066CC"
    
    move_down 10
    
    # Raggruppa appunti per scuola
    appunti_per_scuola = @appunti_dettagliati.group_by do |item|
      {
        scuola_id: item[:appunto].import_scuola_id,
        scuola_nome: item[:appunto].import_scuola&.DENOMINAZIONESCUOLA || "N/D",
        tappa: item[:tappa]
      }
    end
    
    appunti_per_scuola.each_with_index do |(scuola_info, appunti_scuola), scuola_index|
      # Intestazione scuola
      if scuola_index > 0
        move_down 15
      end
      
      text "#{scuola_info[:tappa].position}. #{truncate_text(scuola_info[:scuola_nome], 60)}", 
           size: 12, 
           style: :bold, 
           color: "003366"
      
      move_down 5
      
      # Tabella appunti per questa scuola
      table_data = [["Stato", "Classe", "Nome", "Descrizione"]]
      
      appunti_scuola.each do |item|
        appunto = item[:appunto]
        
        stato = appunto.stato&.titleize || "N/D"
        nome_appunto = appunto.nome&.titleize || "Generico"
        
        # Informazioni sulla classe
        classe_info = ""
        if appunto.classe.present?
          classe_info = "#{appunto.classe.classe} #{appunto.classe.sezione}"
        elsif appunto.import_adozione.present?
          adozione = appunto.import_adozione
          classe_info = "#{adozione.ANNOCORSO} #{adozione.SEZIONEANNO}"
        else
          classe_info = "-"
        end
        
        # Descrizione completa dell'appunto (body + content)
        descrizione_parts = []
        if appunto.body.present?
          descrizione_parts << strip_html_tags(appunto.body)
        end
        if appunto.content.present?
          content_text = strip_html_tags(appunto.content.body.to_s)
          descrizione_parts << content_text if content_text.present?
        end
        descrizione = descrizione_parts.join(" | ")
        descrizione = "Nessuna descrizione" if descrizione.blank?
        
        # Tronca i testi
        descrizione = truncate_text(descrizione, 50)
        
        table_data << [
          stato,
          classe_info,
          nome_appunto,
          descrizione
        ]
      end
      
      table(table_data, 
            header: true,
            width: bounds.width,
            column_widths: [70, 50, 80, bounds.width - 200],
            cell_style: { 
              size: 8, 
              padding: [3, 4],
              border_width: 0.5,
              border_color: "CCCCCC",
              valign: :top
            }) do
        
        # Stile header
        row(0).font_style = :bold
        row(0).background_color = "E6F3FF"
        row(0).text_color = "003366"
        row(0).size = 9
        
        # Allineamento colonne
        column(0).align = :center # Stato
        column(1).align = :center # Classe
        column(2).align = :center # Nome
        column(3).align = :left   # Descrizione
        
        # Colore alternato per le righe
        (1...row_length).each do |i|
          row(i).background_color = i.odd? ? "FFFFFF" : "F8F8F8"
          
          # Evidenzia stati critici
          case table_data[i][0] # colonna stato (ora è la prima)
          when "In Evidenza"
            row(i).background_color = "FFF2CC"
          when "Da Pagare"
            row(i).background_color = "FFE6E6"
          end
        end
      end
      
      # Controlla se c'è spazio per la prossima scuola
      if scuola_index < appunti_per_scuola.count - 1 && cursor < 100
        start_new_page
        intestazione
        move_down 30
        text "APPUNTI PENDENTI (continua)", 
             size: 16, 
             style: :bold, 
             color: "0066CC"
        move_down 10
      end
    end
  end

  def generate_documenti_section
    text "DOCUMENTI PENDENTI", 
         size: 16, 
         style: :bold, 
         color: "CC6600"
    
    move_down 10
    
    # Raggruppa documenti per cliente/scuola
    documenti_per_cliente = @documenti_dettagliati.group_by do |item|
      documento = item[:documento]
      {
        clientable_type: documento.clientable_type,
        clientable_id: documento.clientable_id,
        cliente_nome: case documento.clientable_type
                      when 'ImportScuola'
                        documento.clientable&.DENOMINAZIONESCUOLA || "Scuola N/D"
                      when 'Cliente'
                        documento.clientable&.ragione_sociale || "Cliente N/D"
                      else
                        "N/D"
                      end,
        tappa: item[:tappa]
      }
    end
    
    documenti_per_cliente.each_with_index do |(cliente_info, documenti_cliente), cliente_index|
      # Intestazione cliente/scuola
      if cliente_index > 0
        move_down 15
      end
      
      tipo_cliente = cliente_info[:clientable_type] == 'ImportScuola' ? 'SCUOLA' : 'CLIENTE'
      text "#{cliente_info[:tappa].position}. #{tipo_cliente}: #{truncate_text(cliente_info[:cliente_nome], 55)}", 
           size: 12, 
           style: :bold, 
           color: "663300"
      
      move_down 5
      
      # Tabella documenti per questo cliente/scuola
      table_data = [["Tipo Doc.", "N° Doc.", "Data", "Stato", "Consegnato", "Pagato", "Referente", "Note", "Copie", "Importo"]]
      
      documenti_cliente.each do |item|
        documento = item[:documento]
        
        tipo_doc = documento.causale&.causale || "N/D"
        numero_doc = documento.numero_documento&.to_s || "N/D"
        data_doc = documento.data_documento ? I18n.l(documento.data_documento, format: :short, locale: :it) : "N/D"
        stato = documento.status&.humanize || "N/D"
        
        # Date di consegna e pagamento
        consegnato = documento.consegnato_il ? I18n.l(documento.consegnato_il.to_date, format: :short, locale: :it) : "NO"
        pagato = documento.pagato_il ? I18n.l(documento.pagato_il.to_date, format: :short, locale: :it) : "NO"
        
        # Referente e note
        referente = documento.referente.present? ? truncate_text(documento.referente, 20) : "-"
        note = documento.note.present? ? truncate_text(documento.note, 25) : "-"
        
        # Totale copie calcolato dalle righe
        totale_copie = documento.totale_copie || 0
        
        # Importo calcolato dalle righe
        importo_calcolato = documento.totale_importo
        importo = importo_calcolato > 0 ? "€ #{sprintf('%.2f', importo_calcolato)}" : "-"
        
        # Tronca i testi
        tipo_doc = truncate_text(tipo_doc, 15)
        
        table_data << [
          tipo_doc,
          numero_doc,
          data_doc,
          stato,
          consegnato,
          pagato,
          referente,
          note,
          totale_copie.to_s,
          importo
        ]
      end
      
      table(table_data, 
            header: true,
            width: bounds.width,
            column_widths: [60, 40, 40, 50, 50, 50, 60, 80, 30, bounds.width - 460],
            cell_style: { 
              size: 8, 
              padding: [3, 4],
              border_width: 0.5,
              border_color: "CCCCCC",
              valign: :top
            }) do
        
        # Stile header
        row(0).font_style = :bold
        row(0).background_color = "FFF2E6"
        row(0).text_color = "663300"
        row(0).size = 9
        
        # Allineamento colonne
        column(0).align = :left   # Tipo Doc
        column(1).align = :center # N° Doc
        column(2).align = :center # Data
        column(3).align = :center # Stato
        column(4).align = :center # Consegnato
        column(5).align = :center # Pagato
        column(6).align = :left   # Referente
        column(7).align = :left   # Note
        column(8).align = :center # Copie
        column(9).align = :right  # Importo
        
        # Colore alternato per le righe
        (1...row_length).each do |i|
          row(i).background_color = i.odd? ? "FFFFFF" : "F8F8F8"
          
          # Evidenzia documenti pendenti
          consegnato_val = table_data[i][4] # colonna consegnato
          pagato_val = table_data[i][5] # colonna pagato
          
          if consegnato_val == "NO" && pagato_val == "NO"
            row(i).background_color = "FFE6E6" # Rosso chiaro - né consegnato né pagato
          elsif consegnato_val == "NO" || pagato_val == "NO"
            row(i).background_color = "FFF2CC" # Giallo - solo uno dei due completato
          else
            row(i).background_color = "E6FFE6" # Verde chiaro - tutto completato
          end
        end
      end
      
      # Controlla se c'è spazio per il prossimo cliente
      if cliente_index < documenti_per_cliente.count - 1 && cursor < 100
        start_new_page
        intestazione
        move_down 30
        text "DOCUMENTI PENDENTI (continua)", 
             size: 16, 
             style: :bold, 
             color: "CC6600"
        move_down 10
      end
    end
  end

  def generate_riassunto_titoli_section
    # Controlla se c'è spazio per la sezione
    if cursor < 200
      start_new_page
      intestazione
      move_down 30
    end
    
    text "RIASSUNTO TITOLI DA CONSEGNARE", 
         size: 16, 
         style: :bold, 
         color: "006600"
    
    move_down 10
    
    # Ordina i titoli per quantità decrescente
    titoli_ordinati = @riassunto_titoli.sort_by { |titolo, quantita| -quantita }
    
    # Tabella riassunto
    table_data = [["Titolo", "Quantità Totale"]]
    
    titoli_ordinati.each do |titolo, quantita|
      table_data << [
        truncate_text(titolo, 70),
        quantita.to_s
      ]
    end
    
    # Riga totale
    totale_generale = @riassunto_titoli.values.sum
    table_data << ["TOTALE GENERALE", totale_generale.to_s]
    
    table(table_data, 
          header: true,
          width: bounds.width,
          column_widths: [bounds.width - 80, 80],
          cell_style: { 
            size: 9, 
            padding: [4, 6],
            border_width: 0.5,
            border_color: "CCCCCC",
            valign: :top
          }) do
      
      # Stile header
      row(0).font_style = :bold
      row(0).background_color = "E6FFE6"
      row(0).text_color = "003300"
      row(0).size = 10
      
      # Stile riga totale
      row(-1).font_style = :bold
      row(-1).background_color = "CCFFCC"
      row(-1).text_color = "003300"
      
      # Allineamento colonne
      column(0).align = :left   # Titolo
      column(1).align = :center # Quantità
      
      # Colore alternato per le righe (esclusa l'ultima che è il totale)
      (1...(row_length-1)).each do |i|
        row(i).background_color = i.odd? ? "FFFFFF" : "F8FFF8"
      end
    end
    
    move_down 10
    text "Note: Include solo i documenti non ancora consegnati", 
         size: 8, 
         color: "666666",
         style: :italic
  end

  def get_tappa_name(tappa)
    case tappa.tappable_type
    when 'ImportScuola'
      truncate_text(tappa.tappable.DENOMINAZIONESCUOLA, 20)
    when 'Cliente'
      truncate_text(tappa.tappable.ragione_sociale, 20)
    else
      "N/D"
    end
  end

  def strip_html_tags(text)
    return "" if text.blank?
    text.gsub(/<[^>]*>/, '').gsub(/&nbsp;/, ' ').strip
  end

  def truncate_text(text, max_length)
    return "" if text.blank?
    return text if text.length <= max_length
    "#{text[0..max_length-4]}..."
  end
end
