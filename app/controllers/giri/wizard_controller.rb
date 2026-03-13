module Giri
  class WizardController < ApplicationController
    before_action { @hide_footer_frames = true }
    before_action { @body_class = "wizard-page" }

    # GET /giri/wizard — Step 1 (tipo) + Step 2 (info)
    def new
      @collane = Current.account.collane.ordered
    end

    # GET /giri/wizard/scuole — Step 3 (scuole)
    def scuole
      @tipo_giro = params[:tipo_giro]
      @titolo = params[:titolo]
      @colore = params[:color]
      @collana_id = params[:collana_id]
      @iniziato_il = params[:iniziato_il]
      @finito_il = params[:finito_il]

      @scuole = scuole_per_tipo(@tipo_giro, @collana_id)
      @conteggio = @scuole.size

      respond_to do |format|
        format.html
        format.turbo_stream
      end
    end

    # GET /giri/wizard/riepilogo — Step 4 (conferma)
    def riepilogo
      @tipo_giro = params[:tipo_giro]
      @titolo = params[:titolo]
      @colore = params[:color]
      @collana_id = params[:collana_id]
      @iniziato_il = params[:iniziato_il]
      @finito_il = params[:finito_il]
      @school_ids = Array(params[:school_ids])
      @collana = Collana.find_by(id: @collana_id) if @collana_id.present?
      @conteggio = @school_ids.size
    end

    # POST /giri/wizard — Crea giro + tappe
    def create
      school_ids = Array(params[:school_ids])

      giro = current_user.giri.new(
        titolo: params[:titolo],
        tipo_giro: params[:tipo_giro],
        color: params[:color].presence || "var(--color-card-default)",
        collana_id: params[:collana_id].presence,
        iniziato_il: params[:iniziato_il].presence,
        finito_il: params[:finito_il].presence,
        account: Current.account
      )

      ActiveRecord::Base.transaction do
        giro.save!

        school_ids.each do |school_id|
          tappa = current_user.tappe.create!(
            tappable_type: "Scuola",
            tappable_id: school_id,
            account: Current.account,
            data_tappa: nil
          )
          tappa.tappa_giri.create!(giro: giro)
        end
      end

      redirect_to giro_path(giro), notice: "Giro creato con #{school_ids.size} tappe."
    rescue ActiveRecord::RecordInvalid => e
      redirect_to wizard_giri_path, alert: e.message
    end

    private

    def scuole_per_tipo(tipo, collana_id = nil)
      base = plessi_scope

      case tipo
      when "kit_adozioni"
        base.joins(classi: :adozioni)
            .where(adozioni: { mia: true })
            .distinct
      when "collane"
        base.non_scartate
      when "ritiro_collane"
        base.joins(:bolle_visione)
            .where(bolle_visione: { collana_id: collana_id, user_id: current_user.id })
            .distinct
      when "consegne", "visite"
        base.non_scartate
      else
        base
      end.order(:posizione)
    end

    # Solo plessi e scuole autonome, mai le direzioni
    def plessi_scope
      Current.scuole.where.not(
        id: Scuola.unscoped.select(:direzione_id).where.not(direzione_id: nil)
      )
    end
  end
end
