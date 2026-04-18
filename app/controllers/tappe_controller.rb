class TappeController < ApplicationController

  include FilterScoped

  FILTER_PARAMS = ::Filters::TappaFilter::Fields::PERMITTED_PARAMS

  skip_before_action :set_user_filtering, if: -> { request.format.json? }

  before_action :authenticate_user!
  before_action :set_tappa, only: %i[ show edit update destroy ]

  def index
    base = current_user.tappe

    if request.format.json?
      @tappe = @filter.results(base).order(data_tappa: :asc, position: :asc)
                     .limit(params[:limit] || 50)
      return respond_to { |format| format.json }
    end

    @tappe = @filter.results(base).where.not(data_tappa: nil)

    @scuola = current_account.scuole.find(@filter.scuola_id) if @filter.scuola_id.present?
    @giro   = current_user.giri.find(@filter.giro_id)        if @filter.giro_id.present?

    @current_week_start, @current_week_end, @week_offset = @filter.settimana_info

    @tappe_raggruppate = @tappe.group_by(&:data_tappa)
    @giri_disponibili  = current_user.giri.order(created_at: :desc)

    respond_to do |format|
      format.html do
        if @filter.scuola_id.present? && @filter.sort == "per_data"
          render partial: "tappe_scuola", locals: { tappe: @tappe }
        end
      end
      format.xlsx
      format.turbo_stream
    end
  end

  def show
    load_active_entries
    load_prev_next_tappe

    respond_to do |format|
      format.html
      format.turbo_stream unless flash.any?
      format.json
    end
  end

  def new
    @tappable_type = params[:tappable_type] || "Scuola"
    @tappable_id   = params[:tappable_id]
    @data_tappa    = params[:data_tappa] || Date.today
    @tappa = current_user.tappe.build(
      tappable_id: @tappable_id,
      tappable_type: @tappable_type,
      data_tappa: @data_tappa,
      titolo: params[:source_titolo]
    )
  end

  def edit
    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end

  def create
    @tappa = current_user.tappe.build(tappa_params)

    existing = find_duplicate_tappa(@tappa)
    if existing
      merge_tappa_giri(existing, params[:tappa][:giro_ids])
      respond_to do |format|
        format.html { redirect_to tappa_url(existing), notice: "Tappa già pianificata, giri uniti a quella esistente." }
        format.json { render :show, status: :ok, location: existing }
      end
      return
    end

    respond_to do |format|
      if @tappa.save
        update_tappa_giri(@tappa, params[:tappa][:giro_ids])

        format.html { redirect_to tappa_url(@tappa), notice: "Tappa creata." }
        format.json { render :show, status: :created, location: @tappa }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @tappa.errors, status: :unprocessable_entity }
      end
    end
  end

  def update
    respond_to do |format|
      if @tappa.update(tappa_params)

        update_tappa_giri(@tappa, params[:tappa][:giro_ids])

        format.turbo_stream { flash.now[:notice] = "Tappa aggiornata." }


        format.json { head :no_content }
        format.html { redirect_to @tappa, notice: "Tappa aggiornata." }
      else
        format.json { render json: @tappa.errors, status: :unprocessable_entity }
        format.html { render :edit, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    giorno = @tappa.data_tappa
    @tappa.destroy

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to giorno_path(giorno: giorno), notice: 'Tappa eliminata.' }
      format.json { head :no_content }
    end
  end

  private

    def set_tappa
      @tappa = current_user.tappe.includes(bolle_visione: [:collana, :bolla_visione_righe, { contatto: :classi }]).find(params[:id])
    end

    def load_prev_next_tappe
      tappe_del_giorno = current_user.tappe
        .where(data_tappa: @tappa.data_tappa)
        .order(:position, :id)
        .pluck(:id)

      idx = tappe_del_giorno.index(@tappa.id)
      @prev_tappa_id = idx && idx > 0 ? tappe_del_giorno[idx - 1] : nil
      @next_tappa_id = idx && idx < tappe_del_giorno.size - 1 ? tappe_del_giorno[idx + 1] : nil
    end

    def load_active_entries
      tappable = @tappa.tappable
      return unless tappable.respond_to?(:open_entries)

      @entries = Entry.load_entryables(tappable.open_entries.where.not(entryable_type: "Tappa"))
    end

    def find_tappable
      params[:tappable_type].constantize.find(params[:tappable_id])
    end

    def find_duplicate_tappa(tappa)
      return nil unless tappa.data_tappa.present? && tappa.tappable_type.present? && tappa.tappable_id.present?

      current_user.tappe.find_by(
        tappable_type: tappa.tappable_type,
        tappable_id:   tappa.tappable_id,
        data_tappa:    tappa.data_tappa
      )
    end

    def update_tappa_giri(tappa, giro_ids)
      return if giro_ids.blank?

      # Converte la stringa di ID in un array di interi
      giro_ids_array = giro_ids.split(',').map(&:to_i)

      # Rimuove tutte le associazioni esistenti e crea quelle nuove
      tappa.tappa_giri.destroy_all
      giro_ids_array.each do |giro_id|
        tappa.tappa_giri.create(giro_id: giro_id)
      end
    end

    # Additive: aggiunge i giri passati senza rimuovere quelli esistenti.
    def merge_tappa_giri(tappa, giro_ids)
      return if giro_ids.blank?
      giro_ids.split(',').map(&:to_i).each do |giro_id|
        tappa.tappa_giri.find_or_create_by(giro_id: giro_id)
      end
    end

    def tappa_params
      params.require(:tappa).permit(:tappable, :titolo, :descrizione, :data_tappa, :giro_id, :tappable_id, :tappable_type, :tappable_value, :new_giro, :position, :giro_ids)
    end

   
end
