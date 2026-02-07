# frozen_string_literal: true

class ColumnsController < ApplicationController
  before_action :set_column, only: [:show, :edit, :update, :destroy]

  def index
    @columns = current_account.columns.ordered
  end

  def show
    entries = current_account.entries.non_ssk.active
                .in_column(@column).with_golden_first.recent
                .includes(:goldness, :closure, :not_now)
                .to_a

    # Batch-load entryables (entryable_id is string, can't use includes)
    appunto_ids = entries.select { |e| e.entryable_type == "Appunto" }.map(&:entryable_id)
    documento_ids = entries.select { |e| e.entryable_type == "Documento" }.map(&:entryable_id)

    appunti_by_id = Appunto.where(id: appunto_ids)
                           .includes(:appuntabile, :consegna, righe: :libro)
                           .index_by { |a| a.id.to_s }
    documenti_by_id = Documento.where(id: documento_ids)
                               .includes(:clientable, :consegna, righe: :libro)
                               .index_by { |d| d.id.to_s }

    entries.each do |entry|
      case entry.entryable_type
      when "Appunto"
        entry.instance_variable_set(:@entryable, appunti_by_id[entry.entryable_id])
      when "Documento"
        entry.instance_variable_set(:@entryable, documenti_by_id[entry.entryable_id])
      end
    end

    # Group entries by destinatario
    @grouped_entries = entries.group_by do |e|
      case e.entryable_type
      when "Appunto" then e.entryable&.appuntabile
      when "Documento" then e.entryable&.clientable
      end
    end

    # Volumi da consegnare: documenti non consegnati
    non_consegnati = documenti_by_id.values.reject(&:consegnato?)
    @volumi = non_consegnati.flat_map(&:righe)
                .group_by(&:libro)
                .transform_values { |righe| righe.sum(&:quantita) }
                .sort_by { |libro, _| libro&.titolo.to_s }

    # Adozioni: scuole dai destinatari
    scuola_ids = @grouped_entries.keys.compact.flat_map do |dest|
      case dest
      when Scuola then [dest.id]
      when Classe then [dest.scuola_id]
      else []
      end
    end.uniq

    @adozioni_per_scuola = if scuola_ids.any?
      Adozione.where(account: current_account)
        .mie.da_acquistare_flag
        .joins(:classe)
        .where(classi: { scuola_id: scuola_ids })
        .includes(classe: :scuola)
        .group_by(&:scuola)
    else
      {}
    end
  end

  def new
    @column = current_account.columns.build
  end

  def create
    @column = current_account.columns.create!(column_params)

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to columns_path, notice: "Colonna creata con successo." }
    end
  end

  def edit
  end

  def update
    @column.update!(column_params)

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to columns_path, notice: "Colonna aggiornata con successo." }
    end
  end

  def destroy
    # Capture entries that will be moved to triage before destroying
    @moved_entries = @column.entries.active.includes(:goldness, :closure, :not_now).to_a

    @column.destroy

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to columns_path, notice: "Colonna eliminata con successo." }
    end
  end

  private

  def set_column
    @column = current_account.columns.find(params[:id])
  end

  def column_params
    params.require(:column).permit(:name, :color, :position)
  end
end
