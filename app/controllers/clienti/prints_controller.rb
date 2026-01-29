# frozen_string_literal: true

class Clienti::PrintsController < ApplicationController
  def create
    # TODO: Implement ClientePdf
    flash[:alert] = "Stampa clienti non ancora implementata"
    redirect_to clienti_path
  end
end
