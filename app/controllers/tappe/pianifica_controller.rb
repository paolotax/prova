# frozen_string_literal: true

class Tappe::PianificaController < ApplicationController
  ALLOWED_TYPES = %w[Scuola Cliente Classe Persona Appunto Documento].freeze

  def show
    type = params[:source_type].to_s
    return head :unprocessable_entity unless ALLOWED_TYPES.include?(type)

    @source = type.constantize.find(params[:source_id])
    @target = @source.tappa_target
    return head :not_found unless @target

    @future = Current.user.tappe
      .where(tappable: @target)
      .where("data_tappa >= ?", Date.current)
      .includes(:giri)
      .order(:data_tappa)
  end
end
