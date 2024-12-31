# encoding: utf-8
require "prawn/measurement_extensions"

class AppuntoPdf < Prawn::Document
  
  include LayoutPdf
  
  def initialize(appunti, view)
    super(:page_size => "A4", 
          :page_layout => :portrait,
          :margin => [1.cm, 15.mm],
          :info => {
              :Title => "sovrapacchi",
              :Author => "todo-propa",
              :Subject => "sovrapacchi",
              :Keywords => "sovrapacchi appunti todo-propa",
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
    
    @appunti = appunti
    @view = view

    @appunti.each do |a|
            
      intestazione
      destinatario(a)
      pieghi_di_libri?(a)
      
      note(a)
      
      # start_new_page unless a == @appunti.last
    end
  end

  def intestazione
    logo
    agente(current_user) unless current_user.nil?
  end

  def current_user
    @view.current_user
  end
  
  def pieghi_di_libri?(appunto)
    #stroke_rectangle [0, bounds.top - 100], 16, 150
    text_box("PIEGHI DI LIBRI",
            at: [0, bounds.top - 250],
            size: 13, style: :bold, rotate: 90) # if appunto.tag_list.find_index("posta")
  end
  
  def destinatario(appunto)

    highlight = HighlightCallback.new(color: 'ffff00', document: self)

    bounding_box [bounds.width / 2.0, bounds.top - 150], :width => bounds.width / 2.0, :height => 8.mm do    
      formatted_text(
        [
          { text: "#{appunto.nome}", callback: highlight },
        ],
        size: 14,
      )
    end

    if appunto.scuola.present?
      bounding_box [bounds.width / 2.0, bounds.top - 160], :width => bounds.width / 2.0, :height => 120 do
        move_down(12)
        text appunto.scuola.tipo_scuola,  :size => 12
        text appunto.scuola.scuola,  :size => 14, :style => :bold, :spacing => 4
        move_down(3)
        text appunto.scuola.indirizzo_formattato,  :size => 12
      end
    end
  end

  def note(appunto)

    move_cursor_to bounds.height / 2
    dash([2, 5])  # Imposta lo stile della linea a puntini [lunghezza punto, spazio]
    stroke_horizontal_rule
    undash        # Ripristina lo stile della linea normale
    move_down 30
    text appunto.nome, :size => 13
    text appunto.scuola.to_combobox_display, :size => 12, style: :bold if appunto.scuola.present?
    move_down 10
    if appunto.content.present?
      text @view.sanitize(appunto.content.body.to_s.gsub(/<br>/, " \r ").gsub(/&nbsp;/,"").gsub(/&NoBreak;/,""), attributes: [], tags: []), :size => 13, inline_format: true
    else
      text appunto.body, :size => 13
    end
  end
  
  
  def l(data)
    @view.l data, :format => :only_date
  end
  
  def t(data)
    @view.t data
  end
      


end


