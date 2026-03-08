# encoding: utf-8
require "prawn/measurement_extensions"

class BollaVisionePdf < Prawn::Document

  include LayoutPdf

  def initialize(bolla_visione, view)
    super(
      page_size: "A4",
      page_layout: :portrait,
      margin: [1.cm, 15.mm],
      info: {
        Title: "Bolla Visione #{bolla_visione.numero}",
        Author: "Prova",
        CreationDate: Time.now
      }
    )

    @bolla = bolla_visione
    @scuola = bolla_visione.scuola
    @view = view
    @azienda = Current.account&.azienda
    @righe = bolla_visione.bolla_visione_righe.includes(libro: :editore).order(:position)

    intestazione_azienda
    intestazione_scuola
    intestazione_bolla
    tabella_libri
    footer_totali
  end

  private

  def intestazione_azienda
    bounding_box [bounds.left, bounds.top], width: bounds.width do
      font_size 11
      text @azienda&.ragione_sociale.to_s, size: 13, style: :bold
      text @azienda&.indirizzo.to_s
      text [@azienda&.cap, @azienda&.comune, @azienda&.provincia].compact.join(" ")
      move_down 3
      text "cell.: #{@azienda&.telefono}" if @azienda&.telefono.present?
      text "email: #{@azienda&.email}" if @azienda&.email.present?
    end
  end

  def intestazione_scuola
    bounding_box [bounds.width / 2.0, bounds.top - 50.mm], width: bounds.width / 2.0 do
      text "Spett.le"
      move_down 3
      text @scuola.denominazione, size: 13, style: :bold
      text @scuola.indirizzo.to_s
      text [@scuola.cap, @scuola.comune, @scuola.provincia].compact.join(" ")
      if @bolla.referente.present?
        move_down 3
        text "Att.ne: #{@bolla.referente.nome_completo}", style: :bold
      end
    end
  end

  def intestazione_bolla
    move_down 10

    bounding_box [bounds.left, cursor], width: bounds.width, height: 12.mm do
      fill_color "4A90D9"
      fill_rectangle [bounds.left, bounds.top], bounds.width, bounds.height
      fill_color "FFFFFF"
      text_box "BOLLA VISIONE",
        at: [5.mm, bounds.top - 1.mm],
        width: bounds.width / 2,
        size: 14, style: :bold, valign: :center
      text_box "N. #{@bolla.numero}  del #{@bolla.data_bolla.strftime("%d/%m/%Y")}",
        at: [bounds.width / 2, bounds.top - 1.mm],
        width: bounds.width / 2 - 5.mm,
        size: 11, align: :right, valign: :center
      fill_color "000000"
    end

    if @bolla.note.present?
      move_down 5
      text @bolla.note, size: 9, style: :italic
    end

    move_down 5
  end

  def tabella_libri
    righe_per_disciplina = @righe.group_by { |r| r.libro.disciplina.presence || "Altro" }

    data = []

    # Header
    data << header_row

    righe_per_disciplina.each do |disciplina, righe|
      # Riga separatore disciplina
      data << [{
        content: disciplina.upcase,
        colspan: 4,
        background_color: "E8E8E8",
        font_style: :bold,
        padding: [3, 5],
        size: 8
      }]

      righe.each do |riga|
        data << [
          { content: riga_titolo(riga), size: 7 },
          { content: riga.quantita.to_s, align: :center, size: 8 },
          { content: riga.classi_target.to_s, align: :center, size: 8 },
          { content: riga.libro.editore&.editore.to_s, size: 7 }
        ]
      end
    end

    table data,
      cell_style: { border_width: 0.5, padding: [2, 4] },
      column_widths: { 0 => 95.mm, 1 => 15.mm, 2 => 20.mm, 3 => 50.mm },
      header: true do
        row(0).background_color = "333333"
        row(0).text_color = "FFFFFF"
        row(0).font_style = :bold
        row(0).size = 8
    end
  end

  def header_row
    [
      { content: "Titolo", align: :left },
      { content: "Qta", align: :center },
      { content: "Classi", align: :center },
      { content: "Editore", align: :left }
    ]
  end

  def riga_titolo(riga)
    parts = []
    parts << riga.libro.codice_isbn if riga.libro.codice_isbn.present?
    parts << riga.libro.titolo
    parts.join(" - ")
  end

  def footer_totali
    move_down 10

    font_size 10
    text "Totale copie: #{@righe.sum(&:quantita)}", style: :bold

    move_down 20
    text "Collana: #{@bolla.collana.nome}", size: 9

    move_down 30

    bounding_box [bounds.left, cursor], width: bounds.width / 2.0 do
      text "Firma per ricevuta", size: 9
      move_down 15
      stroke_horizontal_rule
    end

    bounding_box [bounds.width / 2.0, cursor + 25], width: bounds.width / 2.0 do
      text "Data: ___ / ___ / ______", size: 9
    end
  end
end
