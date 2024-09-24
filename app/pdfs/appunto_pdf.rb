# encoding: utf-8
require "prawn/measurement_extensions"
require "prawn-html"

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
          })
    

    
    
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
  
  def pieghi_di_libri?(appunto)
    #stroke_rectangle [0, bounds.top - 100], 16, 150
    text_box("PIEGHI DI LIBRI",
            at: [0, bounds.top - 250],
            size: 13, style: :bold, rotate: 90) # if appunto.tag_list.find_index("posta")
  end
  
  def note(appunto)
    move_down 40
    stroke_horizontal_rule
    move_down 10
    text appunto.nome, :size => 13


    text @view.sanitize(appunto.content.body.to_s.gsub(/<br>/, " \r ").gsub(/&nbsp;/,"").gsub(/&NoBreak;/,""), attributes: [], tags: []), :size => 13, inline_format: true
    #@phtml = PrawnHtml::Instance.new(self)

    #@phtml.append(html: appunto.content.body.to_s)

    #text "tel. #{appunto.telefono}", :size => 13 unless appunto.telefono.blank?
  end
  
  
  def l(data)
    @view.l data, :format => :only_date
  end
  
  def t(data)
    @view.t data
  end
    
  def intestazione
    logo
    agente(current_user) unless current_user.nil?
  end
  

  def destinatario(appunto)
  
    bounding_box [bounds.width / 2.0, bounds.top - 150], :width => bounds.width / 2.0, :height => 120 do
      #stroke_bounds
      #text adozione.team, :size => 14, :style => :bold, :spacing => 4
      move_down(3)
      #text "#{adozione.classe_e_sezione}",  :size => 14, :style => :bold, :spacing => 4      
      move_down(8)
      text appunto.scuola.tipo_scuola,  :size => 12
      text appunto.scuola.scuola,  :size => 14, :style => :bold, :spacing => 4
      move_down(3)
      text appunto.scuola.indirizzo_formattato,  :size => 12
    end
  end


  
  def current_user
    @view.current_user
  end

end
