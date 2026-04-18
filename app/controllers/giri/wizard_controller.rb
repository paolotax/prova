module Giri
  class WizardController < ApplicationController
    before_action { @hide_footer_frames = true }

    # GET /giri/wizard — Step 1 (tipo) + Step dettagli
    def new
      @collane = Current.account.collane.ordered
    end

    # GET /giri/wizard/libri — Step libri (solo kit_adozioni)
    def libri
      @tipo_giro   = params[:tipo_giro]
      @titolo      = params[:titolo]
      @colore      = params[:color]
      @collana_id  = params[:collana_id]
      @iniziato_il = params[:iniziato_il]
      @finito_il   = params[:finito_il]
      @libro_ids   = Array(params[:libro_ids]).reject(&:blank?)

      @libri_gerarchia = libri_mie_attive_gerarchia
      @conteggio = @libri_gerarchia.sum { |_, discipline| discipline.sum { |_, libri| libri.size } }
      @sezioni_per_libro = conta_sezioni_per_libro(@libri_gerarchia)

      respond_to do |format|
        format.html
        format.turbo_stream
      end
    end

    # GET /giri/wizard/scuole — Step scuole
    def scuole
      @tipo_giro   = params[:tipo_giro]
      @titolo      = params[:titolo]
      @colore      = params[:color]
      @collana_id  = params[:collana_id]
      @iniziato_il = params[:iniziato_il]
      @finito_il   = params[:finito_il]
      @libro_ids   = Array(params[:libro_ids]).reject(&:blank?)

      scuole = scuole_per_tipo(@tipo_giro, @collana_id, libro_ids: @libro_ids)
      non_scartate = scuole.non_scartate.to_a
      @scuole_scartate = scuole.scartate_da_utente.to_a
      @conteggio = non_scartate.size
      @gerarchia = Scuola.to_gerarchia(non_scartate)

      respond_to do |format|
        format.html
        format.turbo_stream
      end
    end

    # GET /giri/wizard/riepilogo — Step conferma
    def riepilogo
      @tipo_giro   = params[:tipo_giro]
      @titolo      = params[:titolo]
      @colore      = params[:color]
      @collana_id  = params[:collana_id]
      @iniziato_il = params[:iniziato_il]
      @finito_il   = params[:finito_il]
      @libro_ids   = Array(params[:libro_ids]).reject(&:blank?)
      @school_ids  = Array(params[:school_ids]).reject(&:blank?)
      @collana     = Collana.find_by(id: @collana_id) if @collana_id.present?
      @conteggio   = params[:scuole_count].to_i
      @libri_count = params[:libri_count].to_i
      @libri_riepilogo = libri_riepilogo_per(@libro_ids, @school_ids)
    end

    # POST /giri/wizard — Crea giro + tappe
    def create
      school_ids = Array(params[:school_ids])
      libro_ids  = Array(params[:libro_ids]).reject(&:blank?)

      giro = current_user.giri.new(
        titolo: params[:titolo],
        descrizione: params[:descrizione],
        tipo_giro: params[:tipo_giro],
        color: params[:color].presence || "var(--color-card-default)",
        collana_id: params[:collana_id].presence,
        iniziato_il: params[:iniziato_il].presence,
        finito_il: params[:finito_il].presence,
        conditions: libro_ids.presence ? { libro_ids: libro_ids } : nil,
        account: Current.account
      )

      ActiveRecord::Base.transaction do
        giro.save!
        giro.genera_tappe_per(school_ids: school_ids, user: current_user)
        annota_kit_adozioni!(giro, libro_ids) if params[:tipo_giro] == "kit_adozioni" && libro_ids.any?
      end

      redirect_to giro_path(giro), notice: "Giro creato con #{school_ids.size} tappe."
    rescue ActiveRecord::RecordInvalid => e
      redirect_to wizard_giri_path, alert: e.message
    end

    private

    def scuole_per_tipo(tipo, collana_id = nil, libro_ids: [])
      base = plessi_scope

      case tipo
      when "kit_adozioni"
        rel = base.joins(classi: :adozioni).where(adozioni: { mia: true, disdetta: false })
        rel = rel.where(adozioni: { libro_id: libro_ids }) if libro_ids.present?
        rel.distinct
      when "ritiro_collane"
        base.joins(:bolle_visione)
            .where(bolle_visione: { collana_id: collana_id, user_id: current_user.id })
            .distinct
      else
        base
      end.includes(:direzione).order(:provincia, :area, :denominazione)
    end

    # Solo plessi e scuole autonome, mai le direzioni
    def plessi_scope
      Current.scuole.where.not(
        id: Scuola.unscoped.select(:direzione_id).where.not(direzione_id: nil)
      )
    end

    # { classe_int => { disciplina => [libri] } } ordinato
    def libri_mie_attive_gerarchia
      libri = Current.account.libri
                     .where(id: Adozione.mie_attive.where(account: Current.account).select(:libro_id))
                     .order(:classe, :disciplina, :titolo)

      gerarchia = {}
      libri.each do |libro|
        classe    = libro.classe || 0
        disciplina = libro.disciplina.presence || "(senza disciplina)"
        gerarchia[classe] ||= {}
        gerarchia[classe][disciplina] ||= []
        gerarchia[classe][disciplina] << libro
      end

      gerarchia.sort.to_h.transform_values { |discipline| discipline.sort.to_h }
    end

    # [[libro, adozioni_count], ...] limitato alle scuole selezionate
    def libri_riepilogo_per(libro_ids, school_ids)
      return [] if libro_ids.empty?

      conteggi = Adozione.mie_attive
                         .where(account: Current.account, libro_id: libro_ids)
                         .then { |rel| school_ids.present? ? rel.joins(:classe).where(classi: { scuola_id: school_ids }) : rel }
                         .group(:libro_id).count

      Current.account.libri.where(id: libro_ids).order(:classe, :disciplina, :titolo).map do |libro|
        [libro, conteggi[libro.id].to_i]
      end
    end

    # { libro_id => numero sezioni (classi) con adozione mia_attiva }
    def conta_sezioni_per_libro(gerarchia)
      libri_ids = gerarchia.values.flat_map { |discipline| discipline.values.flatten }.map(&:id)
      return {} if libri_ids.empty?

      Adozione.mie_attive
              .where(account: Current.account, libro_id: libri_ids)
              .group(:libro_id)
              .count
    end

    def annota_kit_adozioni!(giro, libro_ids)
      giro.tappe.reload.includes(:tappable).each do |tappa|
        scuola = tappa.tappable
        next unless scuola.is_a?(Scuola)

        righe = righe_kit_per(scuola, libro_ids)
        next if righe.empty?

        tappa.update!(descrizione: righe.join("\n"))
      end
    end

    # Ritorna un array di stringhe tipo "1A - TITOLO LIBRO" ordinate per classe
    def righe_kit_per(scuola, libro_ids)
      adozioni = Adozione.mie_attive
                         .joins(:classe)
                         .where(classi: { scuola_id: scuola.id })
                         .where(libro_id: libro_ids)
                         .includes(:libro, :classe)

      adozioni.map do |a|
        classe = "#{a.classe.anno_corso}#{a.classe.sezione}"
        [classe, "#{classe} - #{a.libro.titolo.upcase}"]
      end.sort_by(&:first).map(&:last)
    end
  end
end
