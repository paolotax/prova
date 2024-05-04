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
          })
    @appunti = appunti
    @view = view

    @appunti.each do |a|
      
      @righe = a.righe
      intestazione
      destinatario(a)
      pieghi_di_libri?(a)
      
      note(a)
      unless @righe.blank?
        appunto_number(a)
        line_items(a) 
        totali(a)
      end
      
      start_new_page unless a == @appunti.last
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
    text appunto.note, :size => 13
    text "tel. #{appunto.telefono}", :size => 13 unless appunto.telefono.blank?
  end
  
  def appunto_number(appunto)
    move_down 20
    text "ordine \##{appunto.id} del #{l(appunto.created_at)}", size: 13, style: :bold
  end
  
  def line_items(appunto)
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
    @view.l data, :format => :only_date
  end
  
  def t(data)
    @view.t data
  end
  
  def totali(appunto)  
    move_down(10)
    text "Totale copie: #{appunto.totale_copie}", :size => 14, :style => :bold
    text "Totale importo: #{price(appunto.totale_importo)}", :size => 14, :style => :bold
  end
  
  def intestazione
    logo
    agente(current_user) unless current_user.nil?
  end
  
  def destinatario(appunto)
  
    bounding_box [bounds.width / 2.0, bounds.top - 150], :width => bounds.width / 2.0, :height => 100 do
      #stroke_bounds
      text appunto.destinatario, :size => 14, :style => :bold, :spacing => 4
      #move_down(3)
      text "#{appunto.cliente.cognome} #{appunto.cliente.nome}",  :size => 14, :style => :bold, :spacing => 4      
      text appunto.cliente.ragione_sociale,  :size => 14, :style => :bold, :spacing => 4
      text appunto.cliente.indirizzo,  :size => 12
      text appunto.cliente.cap + ' ' + appunto.cliente.frazione  + ' ' + appunto.cliente.comune  + ' ' + appunto.cliente.provincia,  :size => 12

    end
  end
  
  def current_user
    @view.current_user
  end

end
