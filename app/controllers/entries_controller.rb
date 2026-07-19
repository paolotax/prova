# frozen_string_literal: true

class EntriesController < ApplicationController
  before_action :set_entry, only: [:show]

  def index
    @entries = Current.account.entries.published.includes(:column, :goldness, :closure, :not_now)

    # Filter by type
    @entries = @entries.where(entryable_type: params[:type]) if params[:type].present?

    # Filter by state
    case params[:state]
    when "awaiting_triage"
      @entries = @entries.awaiting_triage
    when "triaged"
      @entries = @entries.triaged
    when "closed"
      @entries = @entries.closed
    when "postponed"
      @entries = @entries.postponed
    when "golden"
      @entries = @entries.golden
    end

    # Filter by column
    @entries = @entries.in_column(params[:column_id]) if params[:column_id].present?

    @entries = @entries.with_golden_first.recent.page(params[:page]).per(25)
  end

  def show
    @as = resolve_entry_variant
    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end

  private

  def set_entry
    @entry = current_account.entries.find(params[:id])
  end

  # Vista di default per gli index con vista tabella (deve combaciare con il
  # default passato a resolve_vista nei rispettivi controller).
  VISTA_DEFAULTS = { "documenti" => "tabella", "appunti" => "card" }.freeze

  # Variante di rendering per il refresh dell'entry (es. back-navigation).
  # "row" quando si torna su un index in vista tabella, "card" altrove.
  # Usa il param :as (passato dal JS); in fallback deduce dal referer + cookie,
  # così funziona anche col JS in cache che non passa ancora :as.
  def resolve_entry_variant
    return params[:as] if params[:as].present?

    collection = @entry&.entryable&.model_name&.collection
    default = VISTA_DEFAULTS[collection]
    return nil unless default

    ref_path = (URI(request.referer.to_s).path rescue "")
    on_index = ref_path.match?(%r{/#{collection}/?\z})
    vista = cookies["#{collection}_vista"].presence || default
    return "row" if on_index && vista == "tabella"

    nil
  end
end
