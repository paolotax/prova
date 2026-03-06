# frozen_string_literal: true

require "combine_pdf"

module Entries
  class PrintsController < ApplicationController
    def create
      entries = current_account.entries.where(id: params[:ids]).includes(:entryable)

      appunti = entries.filter_map { |e| e.entryable if e.entryable_type == "Appunto" }
      documenti = entries.filter_map { |e| e.entryable if e.entryable_type == "Documento" }

      combined_pdf = CombinePDF.new

      if appunti.any?
        pdf = AppuntoPdf.new(appunti, view_context)
        temp_file = Tempfile.new(["appunti", ".pdf"])
        pdf.render_file(temp_file.path)
        combined_pdf << CombinePDF.load(temp_file.path)
        temp_file.close
        temp_file.unlink
      end

      documenti.each do |documento|
        pdf = DocumentoPdf.new(documento, view_context)
        temp_file = Tempfile.new(["documento", ".pdf"])
        pdf.render_file(temp_file.path)
        combined_pdf << CombinePDF.load(temp_file.path)
        temp_file.close
        temp_file.unlink
      end

      send_data combined_pdf.to_pdf,
                filename: "entries_#{Time.current.strftime('%Y%m%d')}.pdf",
                type: "application/pdf",
                disposition: "inline"
    end
  end
end
