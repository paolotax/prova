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
          }
    )

    @documento = documento
    @cliente = @documento.clientable
    @view = view

    repeat :all do
      intestazione_cliente(@cliente)
      intestazione_documento
      footer
    end

    # Aggiungo il timbro pagato se il documento è pagato
    if @documento.pagato_il.present?
      # Calcolo le dimensioni del testo per il box
      testo_pagato = "PAGATO"
      testo_data = "#{@documento.pagato_il.strftime("%d/%m/%Y")} - #{@documento.tipo_pagamento}"

      # Imposto il font per calcolare le dimensioni
      font("Helvetica", style: :bold) do
        width_pagato = width_of(testo_pagato, size: 14)
        width_data = width_of(testo_data, size: 8)
        box_width = [width_pagato, width_data].max + 4.mm # padding 2mm per lato

        # Creo il box con le dimensioni calcolate
        bounding_box [bounds.right - box_width - 2.mm, bounds.top + 5.mm],
                    width: box_width,
                    height: 12.mm do

          stroke_color "FF0000"
          fill_color "FFFFFF"
          fill_and_stroke_rounded_rectangle [bounds.left, bounds.top],
                                          bounds.width,
                                          bounds.height,
                                          3

          fill_color "FF0000"
          text_box testo_pagato,
                  at: [bounds.left + 2.mm, bounds.top - 2.mm],
                  width: bounds.width - 4.mm,
                  align: :center,
                  size: 14

          text_box testo_data,
                  at: [bounds.left + 2.mm, bounds.top - 8.mm],
                  width: bounds.width - 4.mm,
                  align: :right,
                  size: 8

          stroke_color "000000"
          fill_color "000000"
        end
      end
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
      text "#{current_user.azienda_ragione_sociale}", :size => 13, :style => :bold
      text "#{current_user.azienda_indirizzo}"
      text "#{current_user.azienda_cap} #{current_user.azienda_comune} #{current_user.azienda_provincia}"
      move_down 5

      text "cell.: #{current_user.azienda_telefono}"
      text "email: #{current_user.azienda_email}"
      text "partita iva: #{current_user.azienda_partita_iva}"
      text "codice fiscale: #{current_user.azienda_codice_fiscale}"

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

    # causale
    bounding_box [bounds.left, bounds.top - 55.mm], :width => 72.mm, :height => 8.mm do

      fill_color @view.string_to_color_hex(@documento.causale.descrizione_causale)

      fill_rectangle [bounds.left, bounds.top], bounds.width, bounds.height

      fill_color "FFFFFF"
      text "#{@documento.causale.descrizione_causale}", align: :center, valign: :center, style: :bold

      draw_bounds

      fill_color "000000"

    end


    # pagina data numero codice cliente
    bounding_box [bounds.left, bounds.top - 63.mm], :width => 72.mm, :height => 8.mm do
      bounding_box [ bounds.left, bounds.top], :width => 8.mm, :height => 8.mm do
        draw_line_left(8.mm)
        draw_text "PAG", :at => [bounds.left + 1, bounds.top - 6], :size => 6
      end
      bounding_box [ bounds.left + 8.mm, bounds.top], :width => 18.mm, :height => 8.mm do
        draw_line_left(8.mm)
        draw_text "DATA", :at => [bounds.left + 1, bounds.top - 6], :size => 6
        bounding_box [ bounds.left + 1.mm, bounds.top - 2.mm ], :width => bounds.width - 2.mm, :height => 6.mm do
          text "#{l(@documento.data_documento, :format => :only_date)}", :align => :center, :valign => :center, :size => 8
        end
      end
      bounding_box [bounds.left + 26.mm, bounds.top], :width => 18.mm, :height => 8.mm do
        draw_line_left(8.mm)
        draw_text "NUMERO", :at => [bounds.left + 1, bounds.top - 6], :size => 6
        bounding_box [ bounds.left + 1.mm, bounds.top - 2.mm ], :width => bounds.width - 2.mm, :height => 6.mm do
          text "#{@documento.numero_documento}", :align => :center, :valign => :center, :size => 8
        end
      end
      bounding_box [bounds.left + 44.mm, bounds.top], :width => 28.mm, :height => 8.mm do
        draw_line_left(8.mm)
        draw_line_right(8.mm)
        draw_text "COD.CLIENTE", :at => [bounds.left + 1, bounds.top - 6], :size => 6
      end
    end

    #condizione di pagamento
    bounding_box [bounds.left, bounds.top - 71.mm], :width => 72.mm, :height => 8.mm do
      draw_bounds
      draw_text "CONDIZIONI DI PAGAMENTO", :at => [bounds.left + 1, bounds.top - 6], :size => 6
      bounding_box [ bounds.left + 1.mm, bounds.top - 2.mm ], :width => bounds.width - 2.mm, :height => 6.mm do
        text "#{@documento.tipo_pagamento}", :align => :center, :valign => :center, :size => 8
      end
    end


    bounding_box [bounds.left, bounds.top - 79.mm], :width => 72.mm, :height => 8.mm do
      bounding_box [ bounds.left, bounds.top], :width => 44.mm, :height => 8.mm do
        draw_line_left(8.mm)
        draw_text "COD. FISCALE", :at => [bounds.left + 1, bounds.top - 6], :size => 6
        bounding_box [ bounds.left + 1.mm, bounds.top - 2.mm ], :width => bounds.width - 2.mm, :height => 6.mm do
          text @documento.clientable&.codice_fiscale, :align => :center, :valign => :center, :size => 8
        end
      end
      bounding_box [ bounds.left + 44.mm, bounds.top], :width => 28.mm, :height => 8.mm do
        draw_line_left(8.mm)
        draw_line_right(8.mm)
        draw_text "PARTITA IVA", :at => [bounds.left + 1, bounds.top - 6], :size => 6
        bounding_box [ bounds.left + 1.mm, bounds.top - 2.mm ], :width => bounds.width - 2.mm, :height => 6.mm do
          text @documento.clientable&.partita_iva, :align => :center, :valign => :center, :size => 8
        end
      end
    end


    bounding_box [bounds.left, bounds.top - 87.mm], :width => 72.mm, :height => 8.mm do

      draw_line_top
      bounding_box [ bounds.left, bounds.top], :width => 15.mm, :height => 8.mm do
        draw_line_left(8.mm)
        draw_text "VALUTA", :at => [bounds.left + 1, bounds.top - 6], :size => 6
        bounding_box [ bounds.left + 1.mm, bounds.top - 2.mm ], :width => bounds.width - 2.mm, :height => 6.mm do
          text "EUR", :align => :center, :valign => :center, :size => 8
        end
      end
      bounding_box [ bounds.left + 15.mm, bounds.top], :width => 57.mm, :height => 8.mm do
        draw_line_left(8.mm)
        draw_line_right(8.mm)
        draw_text "NOSTRO CODICE IBAN PER BONIFICI", :at => [bounds.left + 1, bounds.top - 6], :size => 6
        bounding_box [ bounds.left + 1.mm, bounds.top - 2.mm ], :width => bounds.width - 2.mm, :height => 6.mm do
          text "#{current_user.azienda_iban}", :align => :center, :valign => :center, :size => 8
        end
      end
    end


    bounding_box [bounds.left, bounds.top - 95.mm], :width => bounds.width do
      table [["EAN - Titolo", "Quantità", "Prezzo Unitario", "% Sconto", "Importo", "IVA"]],
            :cell_style => {:border_width   => 0.5, :size => 7},
            :column_widths => { 0 => 72.mm, 1 => 20.mm, 2 => 20.mm, 3 => 20.mm, 4 => 40.mm, 5 => 8.mm } # ,
    end

  end

  def righe_documento
    #  TABLE
    bounding_box([bounds.left, bounds.top - 106.mm], :width  => bounds.width, :height => 135.mm) do
      unless @documento.righe.empty?
        r =  @documento.righe.map do |riga|
          [
            riga.libro.codice_isbn + ' - ' + riga.libro.titolo + ' - ' + riga.libro.editore.editore,
            riga.quantita,
            currency(riga.prezzo),
            riga.sconto,
            currency(riga.importo),
            "VA"
          ]
        end
        table r, :row_colors => ["FFFFFF","DDDDDD"],
                  :cell_style => {:border_width   => 0.5, :size => 7},
                  :column_widths => { 0 => 72.mm, 1 => 20.mm, 2 => 20.mm, 3 => 20.mm, 4 => 40.mm, 5 => 8.mm } do
          cells.columns(1..5).style(:align => :right)
        end
      end

      move_down(15)
      text "Totale copie: #{@documento.totale_copie}", :size => 10
      move_down(10)

      note
    end
  end

  def note
    return if @documento.referente.blank? && @documento.note.blank?

    # Calculate text width without wrapping
    referente_width = width_of("#{@documento.referente}", size: 12)
    note_width = width_of("#{@documento.note}", size: 12)
    max_text_width = [referente_width, note_width].max
    box_width = max_text_width + 20.mm # 10mm padding on each side

    # Limit box width to page width minus margins
    max_width = bounds.width
    box_width = [box_width, max_width].min

    # Calculate text height with the actual box width
    referente_height = height_of_text("#{@documento.referente}", size: 12, width: box_width - 10.mm)
    note_height = height_of_text("#{@documento.note}", size: 12, width: box_width - 10.mm)
    total_height = referente_height + note_height + 10.mm # 10mm for padding

    # Check if we need to start a new page
    if cursor < total_height + 30.mm # 30mm is the space needed for footer
      start_new_page
    end

    bounding_box [bounds.left, cursor], :width => box_width, :height => total_height do
      # Create yellow background box with rounded corners and darker border
      fill_color "FFFFCC"  # Softer yellow for fill
      stroke_color "CCCC00"  # Darker yellow for border
      line_width 1
      fill_and_stroke_rounded_rectangle [bounds.left, bounds.top], bounds.width, bounds.height, 5

      fill_color "000000"  # Reset fill color to black for text

      # Add text with padding
      bounding_box [bounds.left + 5.mm, bounds.top - 5.mm], :width => bounds.width - 10.mm do
        text "#{@documento.referente}", size: 11, style: :bold if @documento.referente.present?
        text "#{@documento.note}", size: 11 if @documento.note.present?
      end
    end
  end

  def footer_totals
    #  FOOTER WITH TOTALS
    bounding_box [bounds.left, bounds.bottom + 28.mm], :width  => bounds.width, :height => 50.mm do

      bounding_box [bounds.left, bounds.top], width: bounds.width, :height => 24.mm do

        bounding_box [bounds.left, bounds.top], :width  => 32.mm, :height => 15.mm do
          bounding_box [ bounds.left + 1.mm, bounds.top - 2.mm ], :width => bounds.width - 2.mm, :height => 6.mm do
            text currency(@documento.totale_importo), :align => :right, :valign => :center, :size => 8
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

        bounding_box [bounds.left + 72.mm, bounds.top], width: bounds.width - bounds.left - 72.mm, :height => 15.mm do
         #draw_bounds
          bounding_box [ bounds.left + 1.mm, bounds.top - 2.mm ], :width => bounds.width - 2.mm, :height => 6.mm do
            text "VA: IVA ass.editore art.74.1.C", :align => :left, :valign => :center, :size => 8
          end
        end

        bounding_box [bounds.left, bounds.top - 15.mm], :width  => 40.mm, :height => 9.mm do
          bounding_box [ bounds.left + 1.mm, bounds.top - 2.mm ], :width => bounds.width - 2.mm, :height => 6.mm do
            text currency(@documento.totale_importo), :align => :right, :valign => :center, :size => 8
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

        bounding_box [bounds.right - 50.mm, bounds.top - 13.mm], :width  => 50.mm, :height => 11.mm do
          bounding_box [ bounds.left + 1.mm, bounds.top - 2.mm ], :width => bounds.width - 2.mm, :height => 8.mm do
            text currency(@documento.totale_importo), :align => :right, :valign => :center, :size => 8
          end
        end
      end
    end
  end

  def footer
    # footer
    bounding_box [bounds.left, bounds.bottom + 28.mm], :width  => bounds.width, :height => 50.mm do

      bounding_box [bounds.left, bounds.top], :width  => bounds.width, :height => 24.mm do

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

        bounding_box [bounds.left + 72.mm, bounds.top], width: bounds.width - bounds.left - 72.mm, :height => 15.mm do

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

        bounding_box [bounds.right - 50.mm, bounds.top - 13.mm], :width  => 50.mm, :height => 11.mm do
          mask(:line_width) do
            line_width 0.5
            stroke_bounds
          end
          draw_text "TOTALE #{@documento.causale.causale.upcase}", :at => [bounds.left + 1, bounds.top - 6], :size => 6, :style => :bold
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

  def draw_line_left(height)
    mask(:line_width) do
      line_width 0.5
      line [bounds.left, bounds.top - height], [bounds.left, bounds.top]
      stroke
    end
  end

  def draw_line_right(height)
    mask(:line_width) do
      line_width 0.5
      line [bounds.right, bounds.top - height], [bounds.right, bounds.top]
      stroke
    end
  end

  def draw_line_top
    mask(:line_width) do
      line_width 0.5
      line [bounds.left, bounds.top], [bounds.right, bounds.top]
      stroke
    end
  end

  def draw_bounds
    mask(:line_width) do
      line_width 0.5
      stroke_bounds
    end
  end

  private

  def currency(number)
    return "€ 0,00" if number.nil?
    sprintf("€ %.2f", number.to_f).gsub(".", ",")
  end

  def height_of_text(text, options = {})
    options[:document] = self
    height_of(text, options)
  end

end