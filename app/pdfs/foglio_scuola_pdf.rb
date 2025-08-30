# encoding: utf-8
require "prawn/measurement_extensions"

class FoglioScuolaPdf < Prawn::Document
  
  include LayoutPdf
  
  def initialize(import_scuole, view:, tipo_stampa: 'tutte_adozioni', con_sovrapacchi: false)
    super(:page_size => "A4", 
          :page_layout => :portrait,
          :margin => [1.cm, 15.mm],
          :info => {
              :Title => "FoglioScuola",
              :Author => "paolotax",
              :Subject => "foglio scuola",
              :Keywords => "sovrapacchi adozioni foglio scuola",
              :Creator => "scagnozz",
              :Producer => "Prawn",
              :CreationDate => Time.now
          })
    
    # Configura encoding UTF-8 per gestire caratteri speciali
    # I caratteri emoji verranno comunque sanitizzati dalla funzione sanitize_text_for_pdf
    
    @view = view
    @tipo_stampa = tipo_stampa
    @con_sovrapacchi = con_sovrapacchi

    import_scuole.each_with_index do |scuola, index|
      start_new_page if index > 0
      
      @scuola = scuola
      @tappe = scuola.tappe
      @adozioni = get_adozioni_per_tipo_stampa(scuola)

      intestazione_e_tappe

      table_adozioni
      table_appunti

      table_seguiti
      
      # Render sovrapacchi per questa scuola solo se richiesto
      render_sovrapacchi_per_scuola(scuola) if @con_sovrapacchi
    end
  end
  
  private
  
  # Sanitizza il testo per rimuovere caratteri non compatibili con Windows-1252
  def sanitize_text_for_pdf(text)
    return "" if text.blank?
    
    begin
      # Tentativo di codifica diretta a Windows-1252
      sanitized = text.encode('Windows-1252', invalid: :replace, undef: :replace, replace: '')
      return sanitized.strip
    rescue => e
      puts "WARNING: Errore encoding #{e.message}, uso sanitizzazione manuale"
    end
    
    # Fallback: sanitizzazione manuale più aggressiva
    sanitized = text.to_s
    
    # Rimuovi tutti i caratteri emoji e simboli Unicode
    sanitized = sanitized.gsub(/[\u{1F000}-\u{1FAFF}]/, '')  # Tutti gli emoji
                        .gsub(/[\u{2000}-\u{2BFF}]/, '')   # Simboli generali
                        .gsub(/[\u{E000}-\u{F8FF}]/, '')   # Area uso privato
    
    # Sostituisci caratteri comuni problematici
    sanitized = sanitized.gsub(/["""]/, '"')     # Smart quotes
                        .gsub(/[''']/, "'")      # Smart apostrophes  
                        .gsub(/[–—]/, "-")       # En/Em dashes
                        .gsub(/…/, "...")        # Ellipsis
                        .gsub(/[°]/, " gradi ")  # Simbolo gradi
    
    # Rimuovi qualsiasi carattere non ASCII rimasto
    sanitized = sanitized.gsub(/[^\x00-\x7F]/, '')
    
    sanitized.strip
  end
  
  def get_adozioni_per_tipo_stampa(scuola)
    case @tipo_stampa
    when 'mie_adozioni'
      # Prendo solo le adozioni dell'utente corrente per questa scuola
      foglio_scuola = Scuole::FoglioScuola.new(scuola: scuola)
      foglio_scuola.mie_adozioni.da_acquistare.sort_by(&:classe_e_sezione_e_disciplina)
    else # 'tutte_adozioni'
      # Prendo tutte le adozioni della scuola
      scuola.import_adozioni.sort_by(&:classe_e_sezione_e_disciplina)
    end
  end
  
  public
  
  def intestazione_e_tappe
    # Layout a 3 colonne dall'alto della pagina
    # 50% intestazione + 25% tappe precedenti + 25% tappe correnti
    
    larghezza_totale = bounds.width
    margine_intestazione = 10  # Piccolo margine destro per l'intestazione
    larghezza_intestazione = (larghezza_totale * 0.5) - margine_intestazione
    larghezza_tappe = larghezza_totale * 0.25
    
    start_y = cursor
    altezza_disponibile = cursor - bounds.bottom  # Spazio disponibile fino al fondo
    puts "DEBUG: altezza_disponibile=#{altezza_disponibile}"
    
    cursors_finali = []
    
    # COLONNA 1: INTESTAZIONE SCUOLA (50%)
    bounding_box([0, start_y], width: larghezza_intestazione, height: altezza_disponibile) do
      text @scuola.tipo_scuola, :size => 12, :spacing => 4
      text @scuola.denominazione, :size => 14, :style => :bold, :spacing => 4      
      text @scuola.indirizzo, :size => 12
      text @scuola.cap + ' ' + @scuola.comune + ' ' + @scuola.provincia, :size => 12
      move_down(10)
      text "cod.min.: #{@scuola.codice_ministeriale}", :size => 10
      text "email: #{@scuola.email}", :size => 10
      stroke_horizontal_rule
      move_down 5
      cursors_finali << cursor
      puts "DEBUG: cursor_intestazione=#{cursor}"
    end
    
    # Prepara dati tappe
    tappe_complete = @tappe.where.not(data_tappa: nil)
                           .select { |t| t.giri.any? || t.titolo.present? }
                           .sort_by(&:data_tappa)
    
    anno_corrente = Date.current.year
    tappe_precedenti = tappe_complete.select { |t| t.data_tappa&.year < anno_corrente }
    tappe_correnti = tappe_complete.select { |t| t.data_tappa&.year >= anno_corrente }
    
    # COLONNA 2: TAPPE PRECEDENTI (25%)
    bounding_box([larghezza_intestazione + margine_intestazione, start_y], width: larghezza_tappe, height: altezza_disponibile) do
      text "PRECEDENTI (#{tappe_precedenti.count})", size: 8, style: :bold, align: :center
      stroke_horizontal_rule
      move_down 3
      
      tappe_precedenti.each do |tappa|
        # Data e giro sulla stessa riga con font diversi
        data_text = tappa.data_tappa&.strftime("%d-%m-%y") || ""
        giro_text = tappa.giri.any? ? " #{tappa.giri.pluck(:titolo).join(", ")}" : ""
        
        formatted_text([
          { text: data_text, size: 7, styles: [:italic] },
          { text: giro_text, size: 7, styles: [:bold] }
        ])
        
        if tappa.titolo.present?
          text tappa.titolo, size: 6
        end
        move_down 3
      end
      cursors_finali << cursor
      puts "DEBUG: cursor_tappe_precedenti=#{cursor}"
    end
    
    # COLONNA 3: TAPPE CORRENTI (25%)
    bounding_box([larghezza_intestazione + margine_intestazione + larghezza_tappe, start_y], width: larghezza_tappe, height: altezza_disponibile) do
      text "#{anno_corrente}+ (#{tappe_correnti.count})", size: 8, style: :bold, align: :center
      stroke_horizontal_rule
      move_down 3
      
      tappe_correnti.each do |tappa|
        # Data e giro sulla stessa riga con font diversi
        data_text = tappa.data_tappa&.strftime("%d-%m-%y") || ""
        giro_text = tappa.giri.any? ? " #{tappa.giri.pluck(:titolo).join(", ")}" : ""
        
        formatted_text([
          { text: data_text, size: 7, styles: [:italic] },
          { text: giro_text, size: 7, styles: [:bold] }
        ])
        
        if tappa.titolo.present?
          text tappa.titolo, size: 6
        end
        move_down 3
      end
      cursors_finali << cursor
      puts "DEBUG: cursor_tappe_correnti=#{cursor}"
    end
    
    # Sposta il cursor principale al punto più basso delle 3 colonne
    cursor_piu_basso = cursors_finali.min
    puts "DEBUG: start_y=#{start_y}, cursors_finali=#{cursors_finali}, cursor_piu_basso=#{cursor_piu_basso}"
    
    # Calcola quanto spazio hanno occupato le colonne + margine
    spazio_occupato = start_y - cursor_piu_basso + 20
    puts "DEBUG: spazio_occupato=#{spazio_occupato}"
    
    # Riposiziona il cursor direttamente al punto più basso + margine
    move_cursor_to cursor_piu_basso - 20
    puts "DEBUG: cursor_finale=#{cursor}"
  end

  def table_adozioni
    
    unless @adozioni.empty?
      
      adozioni_grouped = @adozioni.group_by { |a| [a.classe_e_sezione, a.combinazione] }
      
      adozioni_grouped.each do |riga, adozioni|
        
        classe_table = make_table(
            [
              ["<b>#{riga[0]}</b>"], 
              ["<color rgb='FF00FF'><font size='10'>#{riga[1]}</font></color>"]
            ], position: :left, width: 38.mm, cell_style: { borders: [], inline_format: true }
        )

        data = adozioni.map do |a| 
          [ 
            a.titolo, 
            a.saggi.size > 0 ? a.saggi.size : nil, 
            a.kit.size > 0 ? a.kit.size : nil, 
            a.seguiti.size > 0 ? a.seguiti.size : nil, 
            nil ] 
        end
        data << [ "." ] if data.size > 1

        adozioni_table = make_table(data, width: 142.mm, 
            cell_style: { border_width: 0.5, size: 7 }, 
            column_widths: { 0 => 62.mm, 1 => 20.mm, 2 => 20.mm, 3 => 20.mm, 4 => 20.mm }) do
          
          # Color and style title cells only for mie_adozioni
          adozioni.each_with_index do |a, index|
            if a.mia_adozione?
              if a.da_acquistare?
                row(index).column(0).background_color = "FFFF00"  # Bright yellow for my adoptions da_acquistare
                row(index).column(0).font_style = :bold  # Bold text for my adoptions da_acquistare
              else
                row(index).column(0).background_color = "FFFFCC"  # Pale yellow for my other adoptions
              end
            end
            
            # Stilizzazione celle SSK
            if a.saggi.size > 0
              row(index).column(1).background_color = "FF0000"  # Rosso per saggi
              row(index).column(1).font_style = :bold
              row(index).column(1).text_color = "FFFFFF"       # Testo bianco
              row(index).column(1).align = :center
            end
            
            if a.kit.size > 0
              row(index).column(2).background_color = "FF1493"  # Rosa per kit
              row(index).column(2).font_style = :bold
              row(index).column(2).text_color = "FFFFFF"       # Testo bianco
              row(index).column(2).align = :center
            end
            
            if a.seguiti.size > 0
              row(index).column(3).background_color = "0080FF"  # Azzurro per seguiti
              row(index).column(3).font_style = :bold
              row(index).column(3).text_color = "FFFFFF"       # Testo bianco
              row(index).column(3).align = :center
            end
          end
        end

        rows = []
        rows << [classe_table, adozioni_table]
        table rows, width: 180.mm, column_widths: [38.mm, 142.mm], cell_style: { border_width: 0.5 }, position: :center
      end

      move_down(5)   
    end
  end

  def render_appunti_table(appunti, title, header_color, alternate_color, use_adozione_data: false)
    move_down(10)
      
    # Title for section
    text title, size: 12, style: :bold
    move_down(5)
    
    # Prepare data for the table
    data = [["Classe", "Titolo", "Body / Content", "Stato", "Creato"]]
    
    appunti.each do |appunto|
      # Combine body and content with line breaks
      body_content = []
      if appunto.content.present?
        clean_content = @view.sanitize(appunto.content.body.to_s.gsub(/<br>/, " \r ").gsub(/&nbsp;/,"").gsub(/&NoBreak;/,""), attributes: [], tags: [])
        body_content << sanitize_text_for_pdf(clean_content)
      end
      if appunto.body.present?
        body_content << sanitize_text_for_pdf(appunto.body.to_s)
      end
      
      combined_content = body_content.join("\n")
    
      # Use different data sources based on use_adozione_data flag
      if use_adozione_data && appunto.import_adozione
        titolo_info = sanitize_text_for_pdf(appunto.import_adozione.titolo)
        classe_info = sanitize_text_for_pdf("#{appunto.import_adozione.ANNOCORSO} #{appunto.import_adozione.SEZIONEANNO}")
      else
        titolo_info = sanitize_text_for_pdf(appunto.nome || "")
        classe_info = sanitize_text_for_pdf(appunto.classe&.to_combobox_display || "")
      end
      
      # Debug per identificare testo problematico
      row_data = [
        classe_info,
        titolo_info,
        combined_content,
        sanitize_text_for_pdf(appunto.stato || ""),
        appunto.created_at&.strftime("%d/%m/%Y") || ""
      ]
      
      # Verifica encoding di ogni campo
      row_data.each_with_index do |field, index|
        begin
          field.to_s.encode('Windows-1252')
        rescue => e
          puts "ERROR: Campo #{index} (#{['Classe', 'Titolo', 'Content', 'Stato', 'Data'][index]}) ha caratteri problematici: #{e.message}"
          puts "Contenuto problematico: #{field.inspect}"
          # Forza sanitizzazione aggressiva
          row_data[index] = field.to_s.gsub(/[^\x00-\x7F]/, '?')
        end
      end
      
      data << row_data
    end
      
    # Create and style the table using make_table
    appunti_table = make_table(data, width: 180.mm,
            cell_style: { 
              border_width: 0.5, 
              size: 8, 
              inline_format: true,
              valign: :top
            },
            column_widths: { 
            0 => 20.mm,   # Classe
              1 => 40.mm,   # Titolo  
            2 => 85.mm,   # Body/Content
            3 => 17.5.mm, # Stato
            4 => 17.5.mm  # Creato
          }) do
        
      # Header row styling
      row(0).font_style = :bold
      row(0).background_color = header_color
        
      # Alternate row colors for better readability
      (1...row_length).each do |i|
        row(i).background_color = alternate_color if i.odd?
      end
      
      # Allow rows to expand based on content
      cells.style do |cell|
        cell.height = nil  # Let height adjust automatically
      end
    end
    
    # Position the table
    table [[appunti_table]], width: 180.mm, cell_style: { border_width: 0 }, position: :center
      
    move_down(10)
  end

  def table_appunti
    appunti = @scuola.appunti.non_archiviati.order(created_at: :desc)
    render_appunti_table(appunti, "APPUNTI", "DDDDDD", "F9F9F9") unless appunti.empty?
  end

  def table_seguiti
    seguiti = @scuola.appunti.where(nome: 'seguito').includes(:classe).order(created_at: :desc)
    render_appunti_table(seguiti, "SEGUITI", "CCE5FF", "F0F8FF", use_adozione_data: true) unless seguiti.empty?
  end
    
  def render_sovrapacchi_per_scuola(scuola)
    # Ottieni le adozioni per questa scuola che sono da acquistare e sono mie adozioni
    adozioni_sovrapacchi = scuola.import_adozioni
                                  .where(EDITORE: current_user.miei_editori)
                                  .where(DAACQUIST: 'Si')
                                  .sort_by(&:classe_e_sezione_e_disciplina)

    unless adozioni_sovrapacchi.empty?
      # Inizia una nuova pagina per i sovrapacchi
      start_new_page
      
      # Renderizza 4 sovrapacchi per pagina in verticale, ognuno 1/4 della pagina
      render_sovrapacchi_verticale(adozioni_sovrapacchi, scuola)
    end
  end

  def render_sovrapacchi_verticale(adozioni_sovrapacchi, scuola)
    # Gestisce il rendering di 4 sovrapacchi per pagina in verticale
    # Calcola l'altezza di ogni sovrapacco: 1/4 della pagina
    altezza_sovrapacco = bounds.height / 3.0
    
    adozioni_sovrapacchi.each_slice(3).each_with_index do |gruppo_adozioni, page_index|
      if page_index > 0
        start_new_page
      end
      
      gruppo_adozioni.each_with_index do |adozione, index|
        # Calcola la posizione Y per questo sovrapacco
        y_position = bounds.top - (index * altezza_sovrapacco)
        
        # Usa bounding_box per limitare ogni sovrapacco a 1/4 della pagina
        bounding_box([0, y_position], width: bounds.width, height: altezza_sovrapacco) do
          render_sovrapacco_singolo(adozione, scuola)
          
          # Aggiungi una linea di separazione in fondo (tranne per l'ultimo)
          if index < 3 && index < gruppo_adozioni.length - 1
            move_cursor_to 0
            dash([2, 5])
            stroke_horizontal_rule
            undash
          end
        end
      end
    end
  end

  def render_sovrapacco_singolo(adozione, scuola)
    # Layout con logo a sinistra e contenuto a destra
    
    # Salva la posizione Y iniziale del sovrapacco
    start_y = cursor
    
    # Area per logo a sinistra (30% della larghezza)
    larghezza_sinistra = bounds.width * 0.3
    # Area per contenuto a destra (70% della larghezza) 
    larghezza_destra = bounds.width * 0.7
    x_position_destra = larghezza_sinistra

    # Logo ruotato a sinistra in area limitata
    bounding_box([0, start_y], width: larghezza_sinistra, height: bounds.height) do
      #stroke_bounds
      
      agente_ruotato(current_user) unless current_user.nil?
      logo_ruotato(adozione.editore)
    end

    # Contenuto a destra ripartendo dall'alto
    bounding_box([x_position_destra, start_y], width: larghezza_destra, height: bounds.height) do
      #stroke_bounds

      move_down(40)
      # Classe evidenziata
      highlight = HighlightCallback.new(color: 'ffff00', document: self)
      
      # Destinatario (classe)
      formatted_text(
        [
          { text: "Classe #{adozione.classe_e_sezione}", callback: highlight },
        ],
        size: 14,
        style: :bold
      )
      move_down(3)
      
      # Nome e città della scuola
      text "#{scuola.to_combobox_display}", size: 10, style: :italic
      
      move_down(75)
      
      # Materiale abbinato
      text "Materiale abbinato al testo in adozione:".upcase, size: 10
      move_down(5)
      
      # Titolo evidenziato
      formatted_text(
        [
          { text: "#{adozione.titolo}", styles: [:bold] },
        ],
        size: 14,
        spacing: 4
      )
      move_down(5)
      
      text "Editore: #{adozione.editore}", size: 12, spacing: 4
      text "Disciplina: #{adozione.disciplina.truncate(40)}", size: 12, spacing: 4
      
      # Pallini colorati con quantità affiancati
      if adozione.saggi.any? || adozione.seguiti.any? || adozione.kit.any?
        move_down(15)
        x_position = bounds.left + 8
        y_position = cursor
        
        if adozione.saggi.any?
          # Pallino rosso per saggi
          fill_color "FF0000"
          fill_circle [x_position, y_position], 8
          fill_color "FFFFFF"  # Testo bianco
          text_box "#{adozione.saggi.size}", at: [x_position - 8, y_position + 3], width: 16, height: 8, align: :center, size: 8, style: :bold
          x_position += 20
        end

        if adozione.seguiti.any?
          # Pallino blu per seguiti
          fill_color "0080FF"
          fill_circle [x_position, y_position], 8
          fill_color "FFFFFF"  # Testo bianco
          text_box "#{adozione.seguiti.size}", at: [x_position - 8, y_position + 3], width: 16, height: 8, align: :center, size: 8, style: :bold
          x_position += 20
        end

        if adozione.kit.any?
          # Pallino rosa per kit
          fill_color "FF1493"
          fill_circle [x_position, y_position], 8
          fill_color "FFFFFF"  # Testo bianco
          text_box "#{adozione.kit.size}", at: [x_position - 8, y_position + 3], width: 16, height: 8, align: :center, size: 8, style: :bold
        end
        
        fill_color "000000"  # Ripristina colore nero
      end
    end
  end

end
