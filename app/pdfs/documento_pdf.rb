# encoding: utf-8
require "prawn/measurement_extensions"

class DocumentoPdf < Prawn::Document

  include LayoutPdf
  
  def initialize(documento, view)
    super(:page_size => "A4", 
          :page_layout => :portrait,
          :margin => [1.cm, 15.mm],
          :info => {
              :Title => "documento",
              :Author => "todo-propa",
              :Subject => "fatture",
              :Keywords => "documento todo-propa",
              :Creator => "todo-propa",
              :Producer => "Prawn",
              :CreationDate => Time.now
         })
         

    @documento = documento
    @cliente = @documento.clientable
    @view = view

    repeat :all do
      intestazione_cliente(@cliente)
      intestazione_documento
      footer      
    end

    righe_documento
    
    footer_totals
    
    repeat(:all, :dynamic => true) do
      draw_text page_number, :at => [bounds.left + 7, bounds.top - 69.mm], size: 8
    end

  end
  
  def intestazione_cliente(cliente)
    
    bounding_box [bounds.left, bounds.top], :width  => bounds.width do
      
      font_size 11
      line_width 1

      move_down 5
      text "#{current_user.ragione_sociale}", :size => 13, :style => :bold
      text "Via Vestri, 4"
      text "40128 Bologna BO"
      move_down 5

      text "cell #{current_user.cellulare}"
      text "email #{current_user.email}"
      text "partita iva #{current_user.partita_iva}"
      text "codice fiscale {current_user.codice_fiscale}"

      bounding_box [bounds.width / 2.0, bounds.top - 55.mm], :width => bounds.width / 2.0 do
        text 'Spett.le'
        move_down 5
        text cliente.denominazione,  :size => 14, :style => :bold, :spacing => 4
        text cliente.indirizzo
        text cliente.cap + ' ' + cliente.comune + ' ' + cliente.provincia
        
      end
    end

  end

  def intestazione_documento
    
    bounding_box [bounds.left, bounds.top - 55.mm], :width => 44.mm, :height => 8.mm do
      mask(:line_width) do
        line_width 0.5
        stroke_bounds
      end
      text "#{@documento.causale.causale}", :align => :center, :valign => :center
    end


    bounding_box [bounds.left, bounds.top - 63.mm], :width => 72.mm, :height => 8.mm do
      bounding_box [ bounds.left, bounds.top], :width => 8.mm, :height => 8.mm do
        mask(:line_width) do
          line_width 0.5
          stroke_bounds
        end
        draw_text "PAG", :at => [bounds.left + 1, bounds.top - 6], :size => 6
      end
      bounding_box [ bounds.left + 8.mm, bounds.top], :width => 18.mm, :height => 8.mm do
        mask(:line_width) do
          line_width 0.5
          stroke_bounds
        end
        draw_text "DATA", :at => [bounds.left + 1, bounds.top - 6], :size => 6
        bounding_box [ bounds.left + 1.mm, bounds.top - 2.mm ], :width => bounds.width - 2.mm, :height => 6.mm do
          text "#{l(@documento.data_documento, :format => :only_date)}", :align => :center, :valign => :center, :size => 8
        end
      end
      bounding_box [bounds.left + 26.mm, bounds.top], :width => 18.mm, :height => 8.mm do
        mask(:line_width) do
          line_width 0.5
          stroke_bounds
        end
        draw_text "NUMERO", :at => [bounds.left + 1, bounds.top - 6], :size => 6
        bounding_box [ bounds.left + 1.mm, bounds.top - 2.mm ], :width => bounds.width - 2.mm, :height => 6.mm do
          text "#{@documento.numero_documento}", :align => :center, :valign => :center, :size => 8
        end
      end
      bounding_box [bounds.left + 44.mm, bounds.top], :width => 28.mm, :height => 8.mm do
        mask(:line_width) do
          line_width 0.5
          stroke_bounds
        end
        draw_text "COD.CLIENTE", :at => [bounds.left + 1, bounds.top - 6], :size => 6
      end
    end


    bounding_box [bounds.left, bounds.top - 71.mm], :width => 72.mm, :height => 8.mm do
      mask(:line_width) do
        line_width 0.5
        stroke_bounds
      end
      draw_text "CONDIZIONI DI PAGAMENTO", :at => [bounds.left + 1, bounds.top - 6], :size => 6
      bounding_box [ bounds.left + 1.mm, bounds.top - 2.mm ], :width => bounds.width - 2.mm, :height => 6.mm do
        text "#{@documento.tipo_pagamento}", :align => :center, :valign => :center, :size => 8
      end
    end


    bounding_box [bounds.left, bounds.top - 79.mm], :width => 72.mm, :height => 8.mm do
      bounding_box [ bounds.left, bounds.top], :width => 44.mm, :height => 8.mm do
        mask(:line_width) do
          line_width 0.5
          stroke_bounds
        end
        draw_text "COD. FISCALE", :at => [bounds.left + 1, bounds.top - 6], :size => 6
        bounding_box [ bounds.left + 1.mm, bounds.top - 2.mm ], :width => bounds.width - 2.mm, :height => 6.mm do
          text "#{@cliente.codice_fiscale}", :align => :center, :valign => :center, :size => 8
        end
      end
      bounding_box [ bounds.left + 44.mm, bounds.top], :width => 28.mm, :height => 8.mm do
        mask(:line_width) do
          line_width 0.5
          stroke_bounds
        end
        draw_text "PARTITA IVA", :at => [bounds.left + 1, bounds.top - 6], :size => 6
        bounding_box [ bounds.left + 1.mm, bounds.top - 2.mm ], :width => bounds.width - 2.mm, :height => 6.mm do
          text "#{@cliente.partita_iva}", :align => :center, :valign => :center, :size => 8
        end
      end
    end


    bounding_box [bounds.left, bounds.top - 87.mm], :width => 72.mm, :height => 8.mm do
      bounding_box [ bounds.left, bounds.top], :width => 15.mm, :height => 8.mm do
        mask(:line_width) do
          line_width 0.5
          stroke_bounds
        end
        draw_text "VALUTA", :at => [bounds.left + 1, bounds.top - 6], :size => 6
        bounding_box [ bounds.left + 1.mm, bounds.top - 2.mm ], :width => bounds.width - 2.mm, :height => 6.mm do
          text "EUR", :align => :center, :valign => :center, :size => 8
        end
      end
      bounding_box [ bounds.left + 15.mm, bounds.top], :width => 57.mm, :height => 8.mm do
        mask(:line_width) do
          line_width 0.5
          stroke_bounds
        end
        draw_text "NOSTRO CODICE IBAN PER BONIFICI", :at => [bounds.left + 1, bounds.top - 6], :size => 6
        bounding_box [ bounds.left + 1.mm, bounds.top - 2.mm ], :width => bounds.width - 2.mm, :height => 6.mm do
          text "#{current_user.iban}", :align => :center, :valign => :center, :size => 8
        end
      end
    end


    bounding_box [bounds.left, bounds.top - 95.mm], :width => bounds.width do
      table [["Titolo", "Quantità", "Prezzo Unitario", "% Sconto", "Importo", "IVA"]],
            :cell_style => {:border_width   => 0.5, :size => 7},
            :column_widths => { 0 => 72.mm, 1 => 20.mm, 2 => 20.mm, 3 => 20.mm, 4 => 40.mm, 5 => 8.mm } # ,
    end

  end

  def righe_documento
    #  TABLE
    bounding_box([bounds.left, bounds.top - 106.mm], :width  => bounds.width, :height => 135.mm) do

      unless @documento.righe.empty?
        
        #@documento.righe.group_by(&:appunto).each do |a, righe|
        
        
            
          #text "Ordine del #{l a.created_at, :format => :short}", size: 8
          r =  @documento.righe.map do |riga|
            [
              riga.libro.titolo,
              riga.quantita,
              riga.prezzo,
              riga.sconto.round(2),
              riga.importo,
              "VA"
            ]
          end
          table r, :row_colors => ["FFFFFF","DDDDDD"],
                   :cell_style => {:border_width   => 0.5, :size => 7}, 
                   :column_widths => { 0 => 72.mm, 1 => 20.mm, 2 => 20.mm, 3 => 20.mm, 4 => 40.mm, 5 => 8.mm } do
            cells.columns(1..5).style(:align => :right)
          end  
          move_down(5)
        
      end
    end
  end

  def footer_totals
    #  FOOTER WITH TOTALS
    bounding_box [bounds.left, bounds.bottom + 28.mm], :width  => bounds.width, :height => 50.mm do

      bounding_box [bounds.left, bounds.top], :width  => 188.mm, :height => 24.mm do

        bounding_box [bounds.left, bounds.top], :width  => 32.mm, :height => 15.mm do
          bounding_box [ bounds.left + 1.mm, bounds.top - 2.mm ], :width => bounds.width - 2.mm, :height => 6.mm do
            text "#{@documento.totale_importo}", :align => :right, :valign => :center, :size => 8
          end
        end

        bounding_box [bounds.left + 32.mm , bounds.top], :width  => 8.mm, :height => 15.mm do
          bounding_box [ bounds.left + 1.mm, bounds.top - 2.mm ], :width => bounds.width - 2.mm, :height => 6.mm do
            text "0 %", :align => :right, :valign => :center, :size => 8
          end
        end

        bounding_box [bounds.left + 40.mm, bounds.top], :width  => 32.mm, :height => 15.mm do
          bounding_box [ bounds.left + 1.mm, bounds.top - 2.mm ], :width => bounds.width - 2.mm, :height => 6.mm do
            text "0", :align => :right, :valign => :center, :size => 8
          end
        end

        bounding_box [bounds.left + 72.mm, bounds.top], :width  => 108.mm, :height => 15.mm do
          bounding_box [ bounds.left + 1.mm, bounds.top - 2.mm ], :width => bounds.width - 2.mm, :height => 6.mm do
            text "VA: IVA ass.editore art.74.1.C", :align => :left, :valign => :center, :size => 8
          end
        end

        bounding_box [bounds.left, bounds.top - 15.mm], :width  => 40.mm, :height => 9.mm do
          bounding_box [ bounds.left + 1.mm, bounds.top - 2.mm ], :width => bounds.width - 2.mm, :height => 6.mm do
            text "#{@documento.totale_importo}", :align => :right, :valign => :center, :size => 8
          end
        end

        bounding_box [bounds.left + 40.mm, bounds.top - 15.mm], :width  => 32.mm, :height => 9.mm do
          bounding_box [ bounds.left + 1.mm, bounds.top - 2.mm ], :width => bounds.width - 2.mm, :height => 6.mm do
            text "0,00", :align => :right, :valign => :center, :size => 8
          end
        end

        bounding_box [bounds.left + 72.mm, bounds.top - 15.mm], :width  => 32.mm, :height => 9.mm do
          bounding_box [ bounds.left + 1.mm, bounds.top - 2.mm ], :width => bounds.width - 2.mm, :height => 6.mm do
            text "0,00", :align => :right, :valign => :center, :size => 8
          end
        end

        bounding_box [bounds.left + 144.mm, bounds.top - 13.mm], :width  => 44.mm, :height => 11.mm do
          bounding_box [ bounds.left + 1.mm, bounds.top - 2.mm ], :width => bounds.width - 2.mm, :height => 8.mm do
            text "#{@documento.totale_importo}", :align => :right, :valign => :center, :size => 8
          end
        end
      end    
    end
  end
  
  def footer
    # footer
    bounding_box [bounds.left, bounds.bottom + 28.mm], :width  => bounds.width, :height => 50.mm do
    
      bounding_box [bounds.left, bounds.top], :width  => 188.mm, :height => 24.mm do
        mask(:line_width) do
          line_width 0.5
          stroke_bounds
        end
        
        bounding_box [bounds.left, bounds.top], :width  => 32.mm, :height => 15.mm do
          mask(:line_width) do
            line_width 0.5
            stroke_bounds
          end
          draw_text "IMPONIBILE", :at => [bounds.left + 1, bounds.top - 6], :size => 6
        end
        
        bounding_box [bounds.left + 32.mm , bounds.top], :width  => 8.mm, :height => 15.mm do
          mask(:line_width) do
            line_width 0.5
            stroke_bounds
          end
          draw_text "% IVA", :at => [bounds.left + 1, bounds.top - 6], :size => 6
        end
        
        bounding_box [bounds.left + 40.mm, bounds.top], :width  => 32.mm, :height => 15.mm do
          mask(:line_width) do
            line_width 0.5
            stroke_bounds
          end
          draw_text "IMPOSTA", :at => [bounds.left + 1, bounds.top - 6], :size => 6
        end
        
        bounding_box [bounds.left + 72.mm, bounds.top], :width  => 108.mm, :height => 15.mm do

        end
        
        bounding_box [bounds.left, bounds.top - 15.mm], :width  => 40.mm, :height => 9.mm do
          mask(:line_width) do
            line_width 0.5
            stroke_bounds
          end
          draw_text "TOT.INPONIBILE", :at => [bounds.left + 1, bounds.top - 6], :size => 6
        end
        
        bounding_box [bounds.left + 40.mm, bounds.top - 15.mm], :width  => 32.mm, :height => 9.mm do
          mask(:line_width) do
            line_width 0.5
            stroke_bounds
          end
          draw_text "TOTALE IMPOSTA", :at => [bounds.left + 1, bounds.top - 6], :size => 6
        end
        
        bounding_box [bounds.left + 72.mm, bounds.top - 15.mm], :width  => 32.mm, :height => 9.mm do
          mask(:line_width) do
            line_width 0.5
            stroke_bounds
          end
          draw_text "SPESE DI PORTO E IMBALLO", :at => [bounds.left + 1, bounds.top - 6], :size => 6
        end
        
        bounding_box [bounds.left + 144.mm, bounds.top - 13.mm], :width  => 44.mm, :height => 11.mm do
          mask(:line_width) do
            line_width 0.5
            stroke_bounds
          end
          draw_text "TOTALE #{@documento.causale.causale.upcase}   EUR", :at => [bounds.left + 1, bounds.top - 6], :size => 6, :style => :bold
        end
      end    
    end
  end
    


  def price(num)
    
    (num * 100).modulo(2) == 0 ? precision = 2 : precision = 3
    
    @view.number_to_currency(num, :locale => :it, :format => "%n %u", :precision => precision)
  end
  
  def l(data, format)
    @view.l data#, :format => :only_date
  end
  
  def t(data)
    @view.t data
  end

  def current_user
    @view.current_user
  end
  
  
end