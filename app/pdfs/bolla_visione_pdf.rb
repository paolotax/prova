# encoding: utf-8
require "prawn/measurement_extensions"

class BollaVisionePdf < Prawn::Document

  include LayoutPdf

  GRIGIO_CHIARO = "F5F5F5"
  GRIGIO_BORDO = "DDDDDD"
  BLU_HEADER = "2C5F8A"

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
    @classi = @scuola.classi.index_by(&:id)
    @persone = @scuola.persone.index_by(&:id)

    intestazione_azienda
    intestazione_scuola
    intestazione_bolla
    tabella_libri
    footer_totali
  end

  private

  def intestazione_azienda
    bounding_box [bounds.left, bounds.top], width: bounds.width / 2.0 do
      text @azienda&.ragione_sociale.to_s, size: 11, style: :bold
      font_size 8 do
        text @azienda&.indirizzo.to_s, color: "444444"
        text [@azienda&.cap, @azienda&.comune, @azienda&.provincia].compact.join(" "), color: "444444"
        text @azienda&.telefono, color: "444444" if @azienda&.telefono.present?
        text @azienda&.email.to_s, color: "444444" if @azienda&.email.present?
      end
    end
  end

  def intestazione_scuola
    bounding_box [bounds.width / 2.0, bounds.top], width: bounds.width / 2.0 do
      font_size 8 do
        text "Spett.le", color: "888888"
        move_down 2
        text @scuola.denominazione, size: 11, style: :bold
        text @scuola.indirizzo.to_s, color: "444444"
        text [@scuola.cap, @scuola.comune, @scuola.provincia].compact.join(" "), color: "444444"
        if @bolla.contatto.present?
          move_down 2
          text "Att.ne #{@bolla.contatto.nome_completo}", style: :bold
        end
      end
    end
  end

  def intestazione_bolla
    move_down 6

    stroke_color GRIGIO_BORDO
    stroke_horizontal_rule
    move_down 5

    y = cursor
    text_box "Bolla Visione",
      at: [0, y], width: bounds.width / 2, height: 18,
      size: 15, style: :bold, color: BLU_HEADER
    text_box "N. #{@bolla.numero}  —  #{@bolla.data_bolla.strftime("%d/%m/%Y")}",
      at: [bounds.width / 2, y], width: bounds.width / 2, height: 18,
      size: 10, align: :right, valign: :center, color: "666666"

    move_cursor_to y - 18

    font_size 8 do
      text "Collana: #{@bolla.collana.nome}", color: "666666"
    end

    if @bolla.note.present?
      move_down 2
      font_size 8 do
        text @bolla.note, style: :italic, color: "888888"
      end
    end

    move_down 5
    stroke_color GRIGIO_BORDO
    stroke_horizontal_rule
    move_down 4
  end

  def tabella_libri
    gruppo_per_libro = @bolla.collana.collana_libri.pluck(:libro_id, :gruppo).to_h
    righe_per_gruppo = @righe.group_by { |r| gruppo_per_libro[r.libro_id].presence || "Altro" }

    data = []
    data << header_row

    righe_per_gruppo.each do |gruppo, righe|
      data << [{
        content: gruppo,
        colspan: 4,
        background_color: GRIGIO_CHIARO,
        font_style: :bold,
        padding: [3, 5],
        size: 8,
        text_color: "555555"
      }]

      righe.each do |riga|
        data << [
          { content: riga_titolo(riga), size: 12, inline_format: true },
          { content: riga.quantita.to_s, align: :center, size: 12 },
          { content: consegna_label(riga), size: 8, text_color: "555555" },
          { content: "", size: 8, text_color: "555555" }
        ]
      end
    end

    table data,
      cell_style: {
        border_width: 0,
        border_color: GRIGIO_BORDO,
        padding: [3, 5],
        borders: [:bottom],
        border_widths: [0.5, 0, 0.5, 0]
      },
      width: bounds.width,
      header: true do
        row(0).border_widths = [0, 0, 1, 0]
        row(0).border_color = BLU_HEADER
        row(0).text_color = BLU_HEADER
        row(0).font_style = :bold
        row(0).size = 8
        row(0).padding = [3, 5, 4, 5]
    end
  end

  def header_row
    [
      { content: "Titolo", align: :left },
      { content: "Qta", align: :center },
      { content: "Consegnato a", align: :left },
      { content: "Note riconsegna", align: :left }
    ]
  end

  def consegna_label(riga)
    consegna = riga.consegna || {}
    parts = []

    Array(consegna["classe_id"]).each do |cid|
      classe = @classi[cid]
      parts << classe.nome_breve if classe
    end

    Array(consegna["persona_id"]).each do |pid|
      persona = @persone[pid]
      parts << persona.cognome if persona
    end

    if parts.any?
      parts.join(", ")
    elsif riga.classi_target.present?
      "Per classe #{riga.classi_target}"
    else
      ""
    end
  end

  def riga_titolo(riga)
    parts = []
    parts << riga.libro.titolo
    parts << "<font size='7'><color rgb='888888'>#{riga.libro.editore&.editore}</color></font>" if riga.libro.editore.present?
    parts.join("\n")
  end

  def footer_totali
    move_down 8

    stroke_color BLU_HEADER
    stroke_horizontal_rule
    move_down 4

    y = cursor
    font_size 10 do
      text_box "Totale copie", at: [0, y], width: bounds.width / 2, style: :bold
      text_box @righe.sum(&:quantita).to_s, at: [bounds.width / 2, y], width: bounds.width / 2, align: :right, style: :bold
    end

    move_down 30

    bounding_box [bounds.left, cursor], width: bounds.width / 2.0 - 10.mm do
      font_size 9 do
        text "Firma per ricevuta", color: "888888"
        move_down 15
        stroke_color GRIGIO_BORDO
        stroke_horizontal_rule
      end
    end

    bounding_box [bounds.width / 2.0 + 10.mm, cursor + 22], width: bounds.width / 2.0 - 10.mm do
      font_size 9 do
        text "Data _____ / _____ / ___________", color: "888888"
      end
    end
  end
end
