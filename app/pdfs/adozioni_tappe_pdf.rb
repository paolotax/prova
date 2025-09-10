# encoding: utf-8
require "prawn/measurement_extensions"

class AdozioniTappePdf < Prawn::Document
  
  include LayoutPdf
  
  def initialize(adozioni, giorno, view)
    super(:page_size => "A4", 
          :page_layout => :portrait,
          :margin => [1.cm, 15.mm],
          :info => {
              :Title => "Adozioni Tappe del Giorno",
              :Author => "todo-propa",
              :Subject => "Adozioni nelle scuole delle tappe",
              :Keywords => "adozioni tappe scuole todo-propa",
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
    
    @adozioni = adozioni
    @giorno = giorno
    @view = view

    generate_report
  end

  private

  def generate_report
    intestazione
    
    move_down 30
    
    # Titolo del report
    text "ADOZIONI NELLE SCUOLE DELLE TAPPE", 
         size: 18, 
         style: :bold, 
         align: :center
    
    move_down 10
    
    text "Data: #{I18n.l(@giorno, format: :long, locale: :it)}", 
         size: 12, 
         align: :center
    
    move_down 20
    
    if @adozioni.rows.empty?
      text "Nessuna adozione trovata per le tappe di oggi.", 
           size: 14, 
           align: :center, 
           style: :italic
      return
    end
    
    # Raggruppa le adozioni per editore
    adozioni_per_editore = @adozioni.rows.group_by { |row| row[3] } # editore è alla posizione 3
    
    adozioni_per_editore.each_with_index do |(editore, adozioni), index|
      if index > 0
        start_new_page
        intestazione
        move_down 30
      end
      
      generate_editore_section(editore, adozioni)
    end
  end

  def generate_editore_section(editore, adozioni)
    # Titolo editore
    text editore.upcase, 
         size: 16, 
         style: :bold, 
         color: "0066CC"
    
    move_down 15
    
    # Calcola il totale adozioni per questo editore
    totale_adozioni = adozioni.sum { |row| row[0].to_i } # numero_adozioni è alla posizione 0
    
    text "Totale adozioni: #{totale_adozioni}", 
         size: 12, 
         style: :bold
    
    move_down 10
    
    # Raggruppa per disciplina
    adozioni_per_disciplina = adozioni.group_by { |row| row[4] } # disciplina è alla posizione 4
    
    adozioni_per_disciplina.each do |disciplina, adozioni_disciplina|
      generate_disciplina_section(disciplina, adozioni_disciplina)
      move_down 15
    end
  end

  def generate_disciplina_section(disciplina, adozioni)
    # Sottotitolo disciplina
    text disciplina.titleize, 
         size: 14, 
         style: :bold, 
         color: "666666"
    
    move_down 8
    
    # Tabella delle adozioni
    table_data = [["N°", "Titolo", "ISBN", "Scuole e Classi"]]
    
    adozioni.each do |row|
      numero_adozioni = row[0].to_i
      titolo = row[1] || ""
      isbn = row[2] || ""
      classi = row[6] || ""
      
      # Tronca il titolo se troppo lungo
      titolo_troncato = titolo.length > 40 ? "#{titolo[0..37]}..." : titolo
      
      # Formatta le classi per una migliore leggibilità
      classi_formattate = format_classi(classi)
      
      table_data << [
        numero_adozioni.to_s,
        titolo_troncato,
        isbn,
        classi_formattate
      ]
    end
    
    table(table_data, 
          header: true,
          width: bounds.width,
          column_widths: [30, 200, 90, bounds.width - 320],
          cell_style: { 
            size: 9, 
            padding: [4, 6],
            border_width: 0.5,
            border_color: "CCCCCC"
          }) do
      
      # Stile header
      row(0).font_style = :bold
      row(0).background_color = "F0F0F0"
      row(0).text_color = "333333"
      
      # Allineamento colonne
      column(0).align = :center  # Numero
      column(1).align = :left    # Titolo
      column(2).align = :center  # ISBN
      column(3).align = :left    # Classi
      
      # Colore alternato per le righe
      (1...row_length).each do |i|
        row(i).background_color = i.odd? ? "FFFFFF" : "F8F8F8"
      end
    end
  end

  def format_classi(classi_string)
    return "" if classi_string.blank?
    
    # Dividi le classi per ';' e formatta ciascuna
    classi_array = classi_string.split(';').map(&:strip)
    
    # Limita a massimo 3 classi per riga per evitare overflow
    if classi_array.length > 3
      first_three = classi_array[0..2].join(";\n")
      remaining = classi_array.length - 3
      "#{first_three};\n... e altre #{remaining} classi"
    else
      classi_array.join(";\n")
    end
  end
end
