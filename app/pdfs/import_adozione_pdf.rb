# encoding: utf-8
require "prawn/measurement_extensions"

class ImportAdozionePdf < Prawn::Document
  
  include LayoutPdf
  
  def initialize(adozioni, view)
    super(:page_size => "A4", 
          :page_layout => :portrait,
          :margin => [1.cm, 15.mm],
          :info => {
              :Title => "sovrapacchi",
              :Author => "scagnozz",
              :Subject => "sovrapacchi",
              :Keywords => "sovrapacchi adozioni scagnozz",
              :Creator => "paolotax",
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

    @adozioni = adozioni
    @view = view

    @adozioni.each do |a|
      
      @adozione = Array[a]

      intestazione
      
      destinatario(a)
      
      pieghi_di_libri      

      line_items(a)
      
      start_new_page unless a == @adozioni.last
    end
  end
  
  def destinatario(adozione)

    highlight = HighlightCallback.new(color: 'ffff00', document: self)

    bounding_box [bounds.width / 2.0, bounds.top - 150], :width => bounds.width / 2.0, :height => 8.mm do    
      formatted_text(
        [
          { text: "Classe #{adozione.classe_e_sezione}", callback: highlight },
        ],
        size: 14,
      )
    end

    if adozione.import_scuola.present?

      bounding_box [bounds.width / 2.0, bounds.top - 160], :width => bounds.width / 2.0, :height => 120 do
        move_down(12)
        text adozione.import_scuola.tipo_scuola,  :size => 12
        text adozione.import_scuola.scuola,  :size => 14, :style => :bold, :spacing => 4
        move_down(3)
        text adozione.import_scuola.indirizzo_formattato,  :size => 12
      end
    end
  end
        
  def line_items(adozione)
    
    move_cursor_to bounds.height / 2
    dash([2, 5])  # Imposta lo stile della linea a puntini [lunghezza punto, spazio]
    stroke_horizontal_rule
    undash 

    mask(:line_width) do

      move_down 15
      text "Materiale abbinato al testo in adozione:", :size => 12, style: :bold
      move_down 10
      
      highlight = HighlightCallback.new(color: 'ffff00', document: self)
      formatted_text(
        [
          { text: "#{adozione.titolo}", callback: highlight, styles: [:bold] },
        ],
        size: 14,
        spacing: 4
      )
      move_down 5

      text "Editore: #{adozione.editore}", :size => 12, :spacing => 4

      text "Disciplina: #{adozione.disciplina}", :size => 12, :spacing => 4

      # Pallini colorati con quantità affiancati
      if adozione.saggi.any? || adozione.seguiti.any? || adozione.kit.any?
        move_down 15
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
      
      # text "Classe: #{adozione.classe}", :size => 12, :spacing => 4
      # text "Titolo: #{adozione.titolo}", :size => 12, :spacing => 4
    end
  end
    
end
