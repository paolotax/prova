# frozen_string_literal: true

class Appunti::PrintsController < ApplicationController
  include Appunti::BulkResolvable

  # POST /appunti/prints
  # Bulk print selected appunti as PDF
  def create
    @appunti = bulk_appunti

    respond_to do |format|
      format.pdf do
        pdf = AppuntoPdf.new(@appunti, view_context)
        send_data pdf.render,
          filename: "appunti_#{Time.current.to_i}.pdf",
          type: "application/pdf",
          disposition: "inline"
      end
    end
  end
end
