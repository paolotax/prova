# Controller per le classi nested sotto scuole
# Scoped attraverso Current.account e @scuola
module Scuole
  class ClassiController < ApplicationController
    before_action :set_scuola
    before_action :set_classe, only: [:show, :edit, :update, :destroy, :import_adozioni]

    def index
      @classi = @scuola.classi.attive.includes(:adozioni).order(:anno_corso, :sezione)
    end

    def show
      @adozioni = @classe.adozioni
                    .includes(:saggi, :kit_consegne, :seguiti, :libro)
                    .order(:disciplina, :titolo)
      load_prev_next

      respond_to do |format|
        format.html
        format.turbo_stream
      end
    end

    def edit
      respond_to do |format|
        format.html { redirect_to scuola_classe_path(@scuola, @classe) }
        format.turbo_stream
      end
    end

    def update
      if @classe.update(classe_params)
        redirect_to scuola_classe_path(@scuola, @classe)
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def create
      # Importa classi da Views::Classe
      imported = 0
      views_classi.each do |vc|
        Classe.find_or_create_from_view(vc, scuola: @scuola)
        imported += 1
      rescue ActiveRecord::RecordInvalid
        # già esiste, skip
      end

      redirect_to scuola_path(@scuola), notice: "Importate #{imported} classi"
    end

    def destroy
      @classe.destroy
      redirect_to scuola_path(@scuola), notice: "Classe eliminata"
    end

    def import_adozioni
      count = Adozione.import_for_classe(@classe)
      redirect_to scuola_classe_path(@scuola, @classe), notice: "Importate #{count} adozioni"
    end

    private

    def set_scuola
      @scuola = Current.account.scuole.find(params[:scuola_id])
    end

    def set_classe
      @classe = @scuola.classi.find(params[:id])
    end

    def classe_params
      params.require(:classe).permit(:combinazione, :numero_alunni, :note)
    end

    def load_prev_next
      all_ids = @scuola.classi.order(:anno_corso, :sezione).pluck(:id)
      idx = all_ids.index(@classe.id)
      @prev_classe_id = idx && idx > 0 ? all_ids[idx - 1] : nil
      @next_classe_id = idx && idx < all_ids.size - 1 ? all_ids[idx + 1] : nil
    end

    def views_classi
      Views::Classe.where(codice_ministeriale: @scuola.codice_ministeriale)
    end
  end
end
