# encoding: utf-8
require "prawn/measurement_extensions"

# Distinta stampabile delle consegne di un documento: righe già consegnate
# (raggruppate per consegna) e residuo ancora da consegnare.
class DistintaConsegnePdf < Prawn::Document
  def initialize(documento, view)
    super(page_size: "A4",
          page_layout: :portrait,
          margin: [1.cm, 15.mm],
          info: {
            Title: "Distinta consegne",
            Author: "todo-propa",
            Subject: "consegne",
            Creator: "todo-propa",
            Producer: "Prawn",
            CreationDate: Time.now
          })

    @documento = documento
    @cliente = documento.clientable
    @view = view
    @azienda = Current.account&.azienda

    intestazione
    titolo
    sezione_consegnato
    sezione_residuo

    repeat(:all, dynamic: true) do
      draw_text "Pag. #{page_number}", at: [bounds.right - 15.mm, bounds.bottom - 5.mm], size: 8
    end
  end

  private

  def intestazione
    font_size 10

    text "#{@azienda&.ragione_sociale}", size: 12, style: :bold
    text "#{@azienda&.indirizzo}"
    text "#{@azienda&.cap} #{@azienda&.comune} #{@azienda&.provincia}"

    bounding_box [bounds.width / 2.0, bounds.top], width: bounds.width / 2.0 do
      text "Spett.le", size: 9
      text @cliente.try(:denominazione) || @cliente.to_s, size: 12, style: :bold
      text @cliente.try(:indirizzo) || ""
      text [@cliente.try(:cap), @cliente.try(:comune), @cliente.try(:sigla_provincia) || @cliente.try(:provincia)].compact.join(" ")
    end

    move_down 8.mm
  end

  def titolo
    text "DISTINTA CONSEGNE", size: 14, style: :bold
    text "#{@documento.causale&.causale} n. #{@documento.numero_documento} del #{@documento.data_documento&.strftime('%d/%m/%Y')}", size: 10
    if @documento.referente.present?
      text "Referente: #{@documento.referente}", size: 9
    end
    move_down 6.mm
  end

  def sezione_consegnato
    consegne = @documento.consegne.order(:consegnato_il)
      .includes(consegna_righe: { documento_riga: { riga: :libro } })
    return if consegne.empty?

    rows = [ [ { content: "CONSEGNATO — #{@documento.copie_consegnate} copie",
                 colspan: 2, background_color: "DDDDDD", font_style: :bold } ] ]

    consegne.each do |consegna|
      rows << [ { content: "Consegna del #{consegna.consegnato_il&.strftime('%d/%m/%Y')} — #{consegna.copie} copie",
                  colspan: 2, background_color: "F2F2F2", font_style: :italic } ]
      consegna.consegna_righe.each do |consegna_riga|
        libro = consegna_riga.documento_riga.riga.libro
        rows << [ "#{libro&.codice_isbn} — #{libro&.titolo}", consegna_riga.quantita ]
      end
    end

    tabella(rows)
    move_down 6.mm
  end

  def sezione_residuo
    righe_residue = @documento.documento_righe_consegnabili
    residui = @documento.residui_per_documento_riga

    if righe_residue.empty?
      text "Nessun residuo: consegna completata.", size: 10, style: :bold
      return
    end

    rows = [ [ { content: "DA CONSEGNARE — #{@documento.copie_residue_da_consegnare} copie",
                 colspan: 2, background_color: "DDDDDD", font_style: :bold } ] ]

    righe_residue.each do |documento_riga|
      libro = documento_riga.riga.libro
      rows << [ "#{libro&.codice_isbn} — #{libro&.titolo}", residui[documento_riga.id] ]
    end

    tabella(rows)
  end

  def tabella(rows)
    table rows,
          width: bounds.width,
          cell_style: { border_width: 0.5, size: 8, padding: [3, 5] },
          column_widths: { 1 => 20.mm } do
      cells.columns(1).style(align: :right)
    end
  end
end
