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
      
      @adozione = Array[a]
      #@righe = a.righe
      intestazione
      destinatario(a)
      pieghi_di_libri?(a)      
      note(a)

      numero_documento(a)
      line_items(a)

      totali(a)

      footer

    #   unless @righe.blank?
    #     adozione_number(a)
    #     line_items(a) 
    #     totali(a)
    #   end
      
      start_new_page unless a == @adozioni.last
    end
  end

  def intestazione
    logo
    agente(current_user) unless current_user.nil?
  end
  
  def destinatario(adozione)
  
    bounding_box [bounds.width / 2.0, bounds.top - 150], :width => bounds.width / 2.0, :height => 120 do
      #stroke_bounds
      text adozione.team, :size => 14, :style => :bold, :spacing => 4
      move_down(3)
      text "#{adozione.classe_e_sezione}",  :size => 14, :style => :bold, :spacing => 4      
      move_down(8)
      text adozione.scuola.tipo_scuola,  :size => 12
      text adozione.scuola.scuola,  :size => 14, :style => :bold, :spacing => 4
      move_down(3)
      text adozione.scuola.indirizzo_formattato,  :size => 12
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
    mask(:line_width) do
      line_width 0.5
      stroke_horizontal_rule
    end
    move_down 10
    text adozione.note, :size => 13
    #text "tel. #{adozione.telefono}", :size => 13 unless adozione.telefono.blank?
  end
  
  def numero_documento(adozione)
    move_down 20
    bounding_box [bounds.left, bounds.top - 11.5.cm], :width => bounds.width / 2.0, :height => 150 do
      #stroke_bounds
      text "Documento di trasporto", size: 12, style: :bold, align: :left
      move_down(5)
      text "Numero _______ del ____________", size: 12, style: :bold, align: :left
    end
    bounding_box [bounds.width / 2.0, bounds.top - 11.5.cm], :width => bounds.width / 2.0, :height => 30 do
      #stroke_bounds
      text "ordine \##{adozione.id} del #{l(adozione.created_at)}", size: 11, align: :right
    end
    
  end
  
  def line_items(adozione)
    move_down 20

    mask(:line_width) do
      line_width 0.5
      
      table line_item_rows, cell_style: { border_width: 0.5 } do
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
  end

  def line_item_rows

    [["Titolo", "Quantità", "Prezzo copertina", "Sconto", "Prezzo netto", "Importo netto"]] +
    @adozione.map do |item|
      [
        item.libro.titolo + " " + item.classe.classe, 
        item.numero_copie, 
        0, #price(item.libro.prezzo_in_cents), 
        0, #item.sconto == 0.0 ? price(item.prezzo_copertina - item.prezzo) : item.sconto, 
        price(item.prezzo_cents), #price(item.prezzo_cents), 
        price(item.prezzo_cents * item.numero_copie) 
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
    move_down(14)
    text "Totale copie: #{adozione.numero_copie}", :size => 14, :style => :bold, :align => :right
    move_down(3)
    text "Totale importo: #{price(adozione.prezzo_cents * adozione.numero_copie)}", :size => 14, :style => :bold, :align => :right
  end
  


  def footer
    # footer


    bounding_box [bounds.left, bounds.bottom + 30.mm], :width  => bounds.width, :height => 30.mm do    
      mask(:line_width) do
        line_width 0.5
        stroke_horizontal_rule
      end
      move_down(15)
      text "Pagamento con Bonifico - Banca di appoggio: #{current_user.nome_banca}", :size => 11, :style => :bold, :spacing => 4
      move_down(3)
      text "IBAN: #{current_user.iban}",  :size => 12, :style => :bold, :spacing => 4      
      move_down(3)
      text "conto intestato a #{current_user.ragione_sociale}",  :size => 11
      text "indicare nella causale Scuola, Classe e Numero documento",  :size => 11, :spacing => 4

    end
 

  end

  
  def current_user
    @view.current_user
  end

end
