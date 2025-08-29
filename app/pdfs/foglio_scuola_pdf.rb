# encoding: utf-8
require "prawn/measurement_extensions"

class FoglioScuolaPdf < Prawn::Document
  
  include LayoutPdf
  
  def initialize(import_scuole, view:, tipo_stampa: 'tutte_adozioni')
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

    import_scuole.each_with_index do |scuola, index|
      start_new_page if index > 0
      
      @scuola = scuola
      @tappe = scuola.tappe
      @adozioni = get_adozioni_per_tipo_stampa(scuola)

      intestazione_e_tappe

      table_adozioni
      table_appunti
      table_seguiti
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
  
  publicget_adozioni_per_tipo_stampa
    #bounding_box([bounds.left, cursor - 20], :width  => bounds.width, :height => bounds.) do
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
  
  def pieghi_di_libri?(scuola)
    #stroke_rectangle [0, bounds.top - 100], 16, 150
    text_box("PIEGHI DI LIBRI",
            at: [0, bounds.top - 250],
            size: 13, style: :bold, rotate: 90) # if scuola.tag_list.find_index("posta")
  end
  
  def note(scuola)
    move_down 40
    stroke_horizontal_rule
    move_down 10
    text scuola.note, :size => 13
    text "tel. #{scuola.telefono}", :size => 13 unless scuola.telefono.blank?
  end
  
  def appunto_number(scuola)
    move_down 20
    text "ordine \##{scuola.id} del #{l(scuola.created_at)}", size: 13, style: :bold
  end
  
  def line_items(scuola)
    move_down 10
    table line_item_rows do
      row(0).font_style = :bold
      columns(1..5).align = :right
      columns(0).width = 200
      columns(1).width = 60
      # columns(2..3).width = 70
      # columns(5).width = 80
      self.row_colors = ["DDDDDD", "FFFFFF"]
      self.header = true
    end
  end

  def line_item_rows
    [["Titolo", "Quantità", "Pr. copertina", "Sconto", "Prezzo unitario", "Importo"]] +
    @righe.per_libro_id.map do |item|
      [
        item.titolo, 
        item.quantita, 
        price(item.prezzo_copertina), 
        
        item.sconto == 0.0 ? price(item.prezzo_copertina - item.prezzo) : item.sconto, 
        price(item.prezzo_unitario), 
        price(item.importo) ]
    end
  end
  
  def price(num)
    
    (num * 100).modulo(2) == 0 ? precision = 2 : precision = 3
    
    @view.number_to_currency(num, :locale => :it, :format => "%n %u", :precision => precision)
  end
  
  def l(data)
    @view.l data#, :format => :only_date
  end
  
  def t(data)
    @view.t data
  end
  
  def totali(scuola)  
    move_down(10)
    text "Totale copie: #{scuola.totale_copie}", :size => 14, :style => :bold
    text "Totale importo: #{price(scuola.totale_importo)}", :size => 14, :style => :bold
  end
  
  def intestazione
    logo
    agente(current_user) unless current_user.nil?
  end
    
  def current_user
    @view.current_user
  end

  def truncate_text(text, max_length = 30)
    return "" if text.blank?
    text.length > max_length ? "#{text[0...max_length]}..." : text
  end

end
