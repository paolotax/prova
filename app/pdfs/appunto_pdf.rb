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
      
      pieghi_di_libri
      
      note(a)
      
      start_new_page unless a == @appunti.last
    end
  end

  def destinatario(appunto)
    highlight = HighlightCallback.new(color: 'ffff00', document: self)

    # Riga evidenziata: classe/sezione + titolo
    titolo_evidenziato = build_titolo_evidenziato(appunto)

    bounding_box [bounds.width / 2.0, bounds.top - 150], :width => bounds.width / 2.0, :height => 8.mm do
      formatted_text(
        [
          { text: titolo_evidenziato, callback: highlight },
        ],
        size: 14,
      )
    end

    if appunto.appuntabile.present?
      bounding_box [bounds.width / 2.0, bounds.top - 160], :width => bounds.width / 2.0, :height => 120 do
        move_down(12)
        render_appuntabile_details(appunto.appuntabile)
      end
    end
  end

  def build_titolo_evidenziato(appunto)
    parts = []

    # Classe e sezione se appuntabile è Classe
    parts << appunto.appuntabile.classe_e_sezione if appunto.appuntabile.is_a?(Classe)

    # Nome se presente
    parts << appunto.nome if appunto.nome.present?

    parts.compact.join(" - ")
  end

  def render_appuntabile_details(appuntabile)
    case appuntabile
    when Scuola
      text appuntabile.tipo_scuola, size: 12 if appuntabile.tipo_scuola.present?
      text appuntabile.denominazione, size: 14, style: :bold, spacing: 4
      move_down(3)
      text appuntabile.indirizzo_formattato, size: 12
    when Classe
      text appuntabile.tipo_scuola, size: 12 if appuntabile.tipo_scuola.present?
      text appuntabile.scuola_denominazione, size: 14, style: :bold, spacing: 4
      move_down(3)
      text appuntabile.scuola.indirizzo_formattato, size: 12
    when Cliente
      text appuntabile.denominazione, size: 14, style: :bold, spacing: 4
      move_down(3)
      text appuntabile.indirizzo_formattato, size: 12 if appuntabile.respond_to?(:indirizzo_formattato)
    when Persona
      text "#{appuntabile.cognome} #{appuntabile.nome}", size: 14, style: :bold, spacing: 4
      text appuntabile.scuola&.denominazione, size: 12 if appuntabile.scuola.present?
    end
  end

  def note(appunto)
    move_cursor_to bounds.height / 2
    dash([2, 5])  # Imposta lo stile della linea a puntini [lunghezza punto, spazio]
    stroke_horizontal_rule
    undash        # Ripristina lo stile della linea normale
    move_down 30

    # Classe + nome
    parts = []
    parts << appunto.appuntabile.nome_breve if appunto.appuntabile.is_a?(Classe)
    parts << appunto.nome if appunto.nome.present?
    text parts.join(" "), size: 13 if parts.any?

    # Scuola (da Classe o direttamente se appuntabile è Scuola)
    scuola = extract_scuola(appunto.appuntabile)
    text scuola.to_combobox_display, size: 12, style: :bold if scuola.present?

    move_down 10
    if appunto.content.present?
      text @view.sanitize(appunto.content.body.to_s.gsub(/<br>/, " \r ").gsub(/&nbsp;/,"").gsub(/&NoBreak;/,""), attributes: [], tags: []), :size => 13, inline_format: true
    else
      text appunto.body, :size => 13
    end
  end

  # Estrae la scuola dall'appuntabile
  def extract_scuola(appuntabile)
    case appuntabile
    when Scuola then appuntabile
    when Classe then appuntabile.scuola
    when Persona then appuntabile.scuola
    else nil
    end
  end

end