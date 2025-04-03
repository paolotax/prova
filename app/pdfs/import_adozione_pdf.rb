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
          })
    
    self.font_families.update("DejaVuSans" => {
      :normal => "app/assets/stylesheets/DejaVuSans.ttf",
      :bold => "app/assets/stylesheets/dejavu-sans-bold.ttf"
    })
    
    font "DejaVuSans"

    @adozioni = adozioni
    @view = view

    @adozioni.each do |a|
      
      @adozione = Array[a]
      #@righe = a.righe
      intestazione
      destinatario(a)
      pieghi_di_libri?(a)      

      numero_documento(a)
      line_items(a)
      #totali(a)

      #note(a)

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

      move_down(3)
      text "<u>Classe #{adozione.classe_e_sezione}</u>",  :size => 14, :style => :bold, :spacing => 4, :inline_format => true   
      move_down(8)
      text adozione.import_scuola.tipo_scuola,  :size => 12
      text adozione.import_scuola.scuola,  :size => 14, :style => :bold, :spacing => 4
      move_down(3)
      text adozione.import_scuola.indirizzo_formattato,  :size => 12
    end
  end
  
  def pieghi_di_libri?(adozione)
    #stroke_rectangle [0, bounds.top - 100], 16, 150
    text_box("PIEGHI DI LIBRI",
            at: [0, bounds.top - 250],
            size: 13, style: :bold, rotate: 90) # if adozione.tag_list.find_index("posta")
  end
  
  
  def numero_documento(adozione)
    move_down 20
    mask(:line_width) do
      line_width 0.5
      stroke_horizontal_rule
    end
    

    
  end
  
  def line_items(adozione)
    move_down 20

    mask(:line_width) do
      line_width 0.5

      text "Materiale per l'anno scolastico 2025/2026", :size => 14, style: :bold
      move_down 10
      
      text "Editore: #{adozione.editore}", :size => 12, :spacing => 4

      # text "Disciplina: #{adozione.disciplina}", :size => 12, :spacing => 4
      # text "Classe: #{adozione.classe}", :size => 12, :spacing => 4
      # text "Titolo: #{adozione.titolo}", :size => 12, :spacing => 4
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
  
  def totali(adozione)  
    move_down(14)
    text "Totale copie: #{adozione.numero_copie}", :size => 14, :style => :bold, :align => :right
    move_down(3)
    text "Totale importo: #{price(adozione.prezzo_cents * adozione.numero_copie)}", :size => 14, :style => :bold, :align => :right
  end

  def note(adozione)
    move_down 20
    move_down 10
    text "Note", :size => 14, :style => :bold
    text adozione.note, :size => 13
    #text "tel. #{adozione.telefono}", :size => 13 unless adozione.telefono.blank?
  end


  def footer
    # footer
    bounding_box [bounds.left, bounds.bottom + 30.mm], :width  => bounds.width, :height => 30.mm do    
      mask(:line_width) do
        line_width 0.5
        stroke_horizontal_rule
      end
      # move_down(15)
      # text "Pagamento con Bonifico - Banca di appoggio: #{current_user.nome_banca}", :size => 11, :style => :bold, :spacing => 4
      # move_down(3)
      # text "IBAN: #{current_user.iban}",  :size => 12, :style => :bold, :spacing => 4      
      # move_down(3)
      # text "conto intestato a #{current_user.ragione_sociale}",  :size => 11
      # text "indicare nella causale Scuola, Classe e Numero documento",  :size => 11, :spacing => 4

    end
  end



  def price(num)    
    @view.number_to_currency(num.to_f / 100, :locale => :it, :format => "%n %u", :precision => 2)
  end
  
  def l(data)
    @view.l data#, :format => :only_date
  end
  
  def t(data)
    @view.t data
  end
    
  def current_user
    @view.current_user
  end

end
