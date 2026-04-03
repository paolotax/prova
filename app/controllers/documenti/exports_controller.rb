# frozen_string_literal: true

class Documenti::ExportsController < ApplicationController
  include DocumentoScoped

  # GET /documenti/:documento_id/export.xml
  def show
    respond_to do |format|
      format.xml do
        xml_generator = FatturaElettronicaXml.new(@documento)
        xml_content = xml_generator.genera_xml
        send_data xml_content,
                  filename: "IT#{@documento.account.azienda&.partita_iva}_#{@documento.numero_documento}.xml",
                  type: "application/xml",
                  disposition: "attachment"
      end
    end
  end
end
