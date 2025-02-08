# encoding: utf-8
require "prawn/measurement_extensions"

class FoglioScuolaPdf < Prawn::Document
  
  include LayoutPdf
  
  def initialize(import_scuole, view)
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
    @view = view

    import_scuole.each_with_index do |scuola, index|
      start_new_page if index > 0
      
      @scuola = scuola
      @tappe = scuola.tappe
      @adozioni = scuola.import_adozioni.sort_by(&:classe_e_sezione_e_disciplina)

      intestazione_scuola
      table_tappe

      if @cursor_tappe > @cursor_scuola
        move_cursor_to @cursor_scuola
      end

      table_adozioni
    end
  end
  
  def intestazione_scuola
  
    bounding_box [ 0, bounds.top], :width => bounds.width / 2.0, :height => 120 do
      #stroke_bounds
      text @scuola.tipo_scuola, :size => 12, :spacing => 4
      #move_down(3)
      text  @scuola.denominazione,  :size => 14, :style => :bold, :spacing => 4      
      text @scuola.indirizzo,  :size => 12
      text @scuola.cap + ' ' + @scuola.comune  + ' ' + @scuola.provincia,  :size => 12
      move_down(10)
      text "cod.min.: #{@scuola.codice_ministeriale}",  :size => 10
      text "email: #{@scuola.email}",  :size => 10
    end

    @cursor_scuola = cursor
    
  end

  def table_tappe
    
    bounding_box([bounds.right - 200, bounds.top], width: 200) do
      @tappe.each do |t|                    
        bounding_box([bounds.right - 200, cursor], width: 200) do       
            text "#{t&.data_tappa&.strftime("%d-%m")} - #{t.giro&.titolo}", size: 10, style: :bold
            text t.titolo, size: 10

          
            mask(:line_width) do
              line_width 0.5
              #stroke_bounds
            end
        end
        move_down 5
      end
    end
    move_down 20

    @cursor_tappe = cursor
    
  end

  def table_adozioni
    #  TABLE
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

        adozioni_table = make_table(data, width: 150.mm, 
            cell_style: { border_width: 0.5, size: 7 }, 
            column_widths: { 0 => 70.mm, 1 => 20.mm, 2 => 20.mm, 3 => 20.mm, 4 => 20.mm })

        rows = []
        rows << [classe_table, adozioni_table]
        table rows, width: 188.mm, column_widths: [38.mm, 150.mm], cell_style: { border_width: 0.5 }, position: :center
      end

      move_down(5)   
    end
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

end
