# frozen_string_literal: true

class ImportsController < ApplicationController
  before_action :set_import, only: [:show]

  def new
    @import = ImportRecord.new
    @import_type = params[:type] || "libri"
    @import_subtype = params[:subtype]
  end

  def create
    respond_to do |format|
      format.html do
        @import = Current.user.import_records.new(import_params)
        @import.account = current_account

        if @import.save
          ImportProcessJob.perform_later(@import.id)
          redirect_to import_path(@import)
        else
          @import_type = @import.import_type || "libri"
          @import_subtype = params.dig(:import_record, :metadata, :subtype)
          render :new, status: :unprocessable_entity
        end
      end
      format.json do
        result = import_from_json
        render json: result
      end
    end
  end

  def show
  end

  private

  IMPORTERS = {
    "persone" => ::Persone::Importer,
    "libri"   => ::Libri::Importer,
    "clienti" => ::Clienti::Importer
  }.freeze

  def import_from_json
    type = params[:type]
    return import_adozioni_comunicate_from_json if type == "adozioni_comunicate"

    importer_class = IMPORTERS[type]
    return { ok: false, error: "Tipo non valido: #{type}" } unless importer_class

    items = params[:items]&.map { |i| i.permit!.to_h } || []
    on_conflict = params[:on_conflict] || "update"

    if items.any?
      if importer_class == ::Persone::Importer
        importer_class.import_batch(items)
      else
        importer_class.import_batch(items, on_conflict: on_conflict)
      end
    else
      single_params = params.except(:controller, :action, :format, :type, :items, :on_conflict, :import, :account_id).permit!.to_h.symbolize_keys
      single_params.merge!(on_conflict: on_conflict) unless importer_class == ::Persone::Importer
      importer = importer_class.new(**single_params).import

      if importer_class == ::Persone::Importer
        importer.result
      else
        importer.batch_result
      end
    end
  end

  # Firma diversa dagli altri importer (kwargs account/anno_scolastico/fonte/editore
  # + #import_rows(items) + #riepilogo), quindi ramo dedicato invece di IMPORTERS.
  def import_adozioni_comunicate_from_json
    anno_scolastico = params[:anno_scolastico]
    return { ok: false, error: "anno_scolastico obbligatorio" } if anno_scolastico.blank?

    items = params[:items]&.map { |i| i.permit!.to_h } || []

    importer = ::Adozioni::Comunicate::Importer.new(
      account: current_account,
      anno_scolastico: anno_scolastico,
      fonte: "mcp",
      editore: params[:editore].presence
    )
    importer.import_rows(items)
    importer.riepilogo.merge(ok: true)
  end

  def set_import
    @import = current_account.import_records
                             .where(user: Current.user)
                             .find(params[:id])
  end

  def import_params
    params.require(:import_record).permit(:import_type, :file, metadata: {})
  end
end
