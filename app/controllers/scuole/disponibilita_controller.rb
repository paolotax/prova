module Scuole
  class DisponibilitaController < ApplicationController
    before_action :authenticate_user!
    before_action :set_scuola

    def create
      @disponibilita = @scuola.disponibilita.new(disponibilita_params)
      @disponibilita.account = Current.account
      @disponibilita.user = Current.user if @disponibilita.tipo == "nota"

      if @disponibilita.save
        respond_to do |format|
          format.turbo_stream do
            render turbo_stream: turbo_stream.replace(
              ActionView::RecordIdentifier.dom_id(@scuola, :disponibilita),
              partial: "scuole/container/disponibilita",
              locals: { scuola: @scuola.reload }
            )
          end
          format.html { redirect_to scuola_path(@scuola) }
        end
      else
        redirect_to scuola_path(@scuola), alert: @disponibilita.errors.full_messages.join(", ")
      end
    end

    def destroy
      @disponibilita = @scuola.disponibilita.find(params[:id])
      @disponibilita.destroy

      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            ActionView::RecordIdentifier.dom_id(@scuola, :disponibilita),
            partial: "scuole/container/disponibilita",
            locals: { scuola: @scuola.reload }
          )
        end
        format.html { redirect_to scuola_path(@scuola) }
      end
    end

    private

    def set_scuola
      @scuola = Current.account.scuole.find(params[:scuola_id])
    end

    def disponibilita_params
      params.require(:disponibilita).permit(
        :tipo, :giorno_settimana, :data, :ora_inizio, :ora_fine, :titolo, :ricorrente
      )
    end
  end
end
