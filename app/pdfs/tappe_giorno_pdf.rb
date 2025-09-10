# encoding: utf-8
require "prawn/measurement_extensions"

class TappeGiornoPdf < Prawn::Document
  
  include LayoutPdf
  
  def initialize(tappe, giorno, view, appunti_per_tappa = {}, documenti_per_tappa = {})
    super(:page_size => "A4", 
          :page_layout => :portrait,
          :margin => [1.cm, 15.mm],
          :info => {
              :Title => "Tappe del Giorno",
              :Author => "todo-propa",
              :Subject => "Elenco tappe programmate",
              :Keywords => "tappe giri agenda todo-propa",
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
    
    @tappe = tappe
    @giorno = giorno
    @view = view
    @appunti_per_tappa = appunti_per_tappa
    @documenti_per_tappa = documenti_per_tappa

    generate_report
  end

  private

  def generate_report
    intestazione
    
    move_down 30
    
    # Titolo del report
    text "TAPPE DEL GIORNO", 
         size: 18, 
         style: :bold, 
         align: :center
    
    move_down 10
    
    text "Data: #{I18n.l(@giorno, format: :long, locale: :it)}", 
         size: 12, 
         align: :center
    
    move_down 20
    
    if @tappe.empty?
      text "Nessuna tappa programmata per oggi.", 
           size: 14, 
           align: :center, 
           style: :italic
      return
    end
    
    # Informazioni generali
    text "Totale tappe: #{@tappe.count}", 
         size: 12, 
         style: :bold
    
    # Raggruppa per giri se presenti
    giri_tappe = @tappe.group_by { |tappa| tappa.giri.first&.titolo || "Senza giro" }
    
    if giri_tappe.keys.count > 1
      text "Giri coinvolti: #{giri_tappe.keys.reject { |k| k == "Senza giro" }.count}", 
           size: 12
    end
    
    move_down 15
    
    # Genera sezioni per ogni giro
    giri_tappe.each_with_index do |(giro_nome, tappe_giro), index|
      if index > 0 && cursor < 200
        start_new_page
        intestazione
        move_down 30
      end
      
      generate_giro_section(giro_nome, tappe_giro)
      move_down 20
    end
    
    # Riepilogo finale
    if cursor < 150
      start_new_page
      intestazione
      move_down 30
    end
    
    generate_summary
  end

  def generate_giro_section(giro_nome, tappe)
    # Titolo giro
    if giro_nome != "Senza giro"
      text "GIRO: #{giro_nome.upcase}", 
           size: 14, 
           style: :bold, 
           color: "0066CC"
    else
      text "TAPPE SINGOLE", 
           size: 14, 
           style: :bold, 
           color: "666666"
    end
    
    move_down 10
    
    # Tabella delle tappe
    table_data = [["#", "Tipo", "Destinazione", "Indirizzo", "Note"]]
    
    tappe.each_with_index do |tappa, index|
      tipo = tappa.tappable_type == 'ImportScuola' ? 'Scuola' : 'Cliente'
      
      destinazione = case tappa.tappable_type
                     when 'ImportScuola'
                       "#{tappa.tappable.DENOMINAZIONESCUOLA}"
                     when 'Cliente'
                       tappa.tappable.ragione_sociale
                     else
                       tappa.tappable.denominazione rescue "N/D"
                     end
      
      indirizzo = case tappa.tappable_type
                  when 'ImportScuola'
                    "#{tappa.tappable.INDIRIZZOSCUOLA}\n#{tappa.tappable.CAPSCUOLA} #{tappa.tappable.DESCRIZIONECOMUNE} (#{tappa.tappable.PROVINCIA})"
                  when 'Cliente'
                    "#{tappa.tappable.indirizzo}\n#{tappa.tappable.cap} #{tappa.tappable.citta}"
                  else
                    "N/D"
                  end
      
      # Costruiamo le note con informazioni su appunti e documenti
      note_parts = []
      
      # Aggiungi titolo e descrizione se presenti
      if tappa.titolo.present?
        note_parts << tappa.titolo
      end
      if tappa.descrizione.present?
        note_parts << tappa.descrizione
      end
      
      # Aggiungi informazioni su appunti pendenti
      appunti_count = @appunti_per_tappa[tappa.id] || 0
      if appunti_count > 0
        note_parts << "[A] #{appunti_count} appunt#{appunti_count == 1 ? 'o' : 'i'} pendenti"
      end
      
      # Aggiungi informazioni su documenti pendenti
      documenti_count = @documenti_per_tappa[tappa.id] || 0
      if documenti_count > 0
        note_parts << "[D] #{documenti_count} document#{documenti_count == 1 ? 'o' : 'i'} pendenti"
      end
      
      note = note_parts.empty? ? "-" : note_parts.join(" • ")
      
      # Tronca i testi se troppo lunghi
      destinazione = truncate_text(destinazione, 35)
      indirizzo = truncate_text(indirizzo, 30)
      note = truncate_text(note, 45)
      
      table_data << [
        (index + 1).to_s,
        tipo,
        destinazione,
        indirizzo,
        note
      ]
    end
    
    table(table_data, 
          header: true,
          width: bounds.width,
          column_widths: [25, 50, 130, 120, bounds.width - 325],
          cell_style: { 
            size: 8, 
            padding: [3, 4],
            border_width: 0.5,
            border_color: "CCCCCC",
            valign: :top
          }) do
      
      # Stile header
      row(0).font_style = :bold
      row(0).background_color = "F0F0F0"
      row(0).text_color = "333333"
      row(0).size = 9
      
      # Allineamento colonne
      column(0).align = :center  # Numero
      column(1).align = :center  # Tipo
      column(2).align = :left    # Destinazione
      column(3).align = :left    # Indirizzo
      column(4).align = :left    # Note
      
      # Colore alternato per le righe
      (1...row_length).each do |i|
        row(i).background_color = i.odd? ? "FFFFFF" : "F8F8F8"
      end
    end
  end

  def generate_summary
    stroke_horizontal_rule
    move_down 15
    
    text "RIEPILOGO", size: 14, style: :bold
    move_down 10
    
    # Conta per tipo
    scuole_count = @tappe.count { |t| t.tappable_type == 'ImportScuola' }
    clienti_count = @tappe.count { |t| t.tappable_type == 'Cliente' }
    
    summary_data = [
      ["Tipo destinazione", "Quantità"],
      ["Scuole", scuole_count.to_s],
      ["Clienti", clienti_count.to_s],
      ["TOTALE", @tappe.count.to_s]
    ]
    
    table(summary_data,
          header: true,
          position: :left,
          width: 200,
          cell_style: { 
            size: 10, 
            padding: [4, 8],
            border_width: 0.5,
            border_color: "CCCCCC"
          }) do
      
      row(0).font_style = :bold
      row(0).background_color = "F0F0F0"
      row(-1).font_style = :bold  # Ultima riga (totale)
      column(1).align = :center
    end
    
    move_down 15
    
    # Note aggiuntive
    text "Note:", size: 10, style: :bold
    text "• Le tappe sono ordinate per posizione programmata", size: 9
    text "• [A] = Appunti pendenti, [D] = Documenti non consegnati o non pagati", size: 9
    text "• Controllare gli indirizzi prima della partenza", size: 9
    text "• Report generato il #{Time.current.strftime('%d/%m/%Y alle %H:%M')}", size: 8, color: "666666"
  end

  def truncate_text(text, max_length)
    return text if text.length <= max_length
    "#{text[0..max_length-4]}..."
  end
end
