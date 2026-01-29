# frozen_string_literal: true

require "combine_pdf"

module Documenti
  class PrintsController < ApplicationController
    def create
      combined_pdf = CombinePDF.new

      current_account.documenti.where(id: params[:ids]).find_each do |documento|
        pdf = DocumentoPdf.new(documento, view_context)
        temp_file = Tempfile.new(["documento", ".pdf"])
        pdf.render_file(temp_file.path)
        combined_pdf << CombinePDF.load(temp_file.path)
        temp_file.close
        temp_file.unlink
      end

      send_data combined_pdf.to_pdf,
                filename: "documenti_#{Time.current.strftime('%Y%m%d')}.pdf",
                type: "application/pdf",
                disposition: "inline"
    end
  end
end
