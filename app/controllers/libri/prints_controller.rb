# frozen_string_literal: true

class Libri::PrintsController < ApplicationController
  def create
    # TODO: Implement LibroPdf
    flash[:alert] = "Stampa libri non ancora implementata"
    redirect_to libri_path
  end
end
