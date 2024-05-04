# encoding: utf-8
require "prawn/measurement_extensions"

class AdozionePdf < Prawn::Document
  
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
          })
    @adozioni = adozioni
    @view = view

    @adozioni.each do |a|
      
      #@righe = a.righe
      intestazione
      destinatario(a)
      pieghi_di_libri?(a)


      
      note(a)

      adozione_number(a)
      line_items(@adozioni)

    #   unless @righe.blank?
    #     adozione_number(a)
    #     line_items(a) 
    #     totali(a)
    #   end
      
      start_new_page unless a == @adozioni.last
    end
  end
  
  def pieghi_di_libri?(adozione)
    #stroke_rectangle [0, bounds.top - 100], 16, 150
    text_box("PIEGHI DI LIBRI",
            at: [0, bounds.top - 250],
            size: 13, style: :bold, rotate: 90) # if adozione.tag_list.find_index("posta")
  end
  
  def note(adozione)
    move_down 40
    stroke_horizontal_rule
    move_down 10
    text adozione.note, :size => 13
    #text "tel. #{adozione.telefono}", :size => 13 unless adozione.telefono.blank?
  end
  
  def adozione_number(adozione)
    move_down 20
    text "ordine \##{adozione.id} del #{l(adozione.created_at)}", size: 13, style: :bold
  end
  
  def line_items(adozione)
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
    @adozioni.map do |item|
      [
        item.libro.titolo + " " + item.classe.classe, 
        item.numero_copie, 
        price(item.libro.prezzo_in_cents), 
        0, #item.sconto == 0.0 ? price(item.prezzo_copertina - item.prezzo) : item.sconto, 
        0, #price(item.prezzo_cents), 
        0  #price(item.importo_cents) 
      ]
    end
  end
  
  def price(num)    
    @view.number_to_currency(num.to_f / 100, :locale => :it, :format => "%n %u", :precision => 2)
  end
  
  def l(data)
    @view.l data, :format => :only_date
  end
  
  def t(data)
    @view.t data
  end
  
  def totali(adozione)  
    move_down(10)
    text "Totale copie: #{adozione.totale_copie}", :size => 14, :style => :bold
    text "Totale importo: #{price(adozione.totale_importo)}", :size => 14, :style => :bold
  end
  
  def intestazione
    logo
    agente(current_user) unless current_user.nil?
  end
  
  def destinatario(adozione)
  
    bounding_box [bounds.width / 2.0, bounds.top - 150], :width => bounds.width / 2.0, :height => 100 do
      #stroke_bounds
      text adozione.team, :size => 14, :style => :bold, :spacing => 4
      #move_down(3)
      text "#{adozione.classe_e_sezione}",  :size => 14, :style => :bold, :spacing => 4      
      text adozione.scuola.scuola,  :size => 14, :style => :bold, :spacing => 4
      text adozione.scuola.indirizzo,  :size => 12
      #text adozione.cliente.cap + ' ' + adozione.cliente.frazione  + ' ' + adozione.cliente.comune  + ' ' + adozione.cliente.provincia,  :size => 12

    end
  end
  
  def current_user
    @view.current_user
  end

end
