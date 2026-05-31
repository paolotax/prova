class Libri::FascicoliController < ApplicationController
  before_action :authenticate_user!
  before_action :set_libro

  def index
    # Ricerca combobox: cerca tra i candidati a fascicolo di QUESTA confezione
    if params[:q].present?
      candidati = current_account.libri.fascicoli_candidati_per(@libro).search_all_word(params[:q])
      set_page_and_extract_portion_from candidati
      return render :index, formats: [:turbo_stream]
    end

    @fascicoli = @libro.fascicoli
    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end

  def create
    @pivot = @libro.confezione_righe.create!(pivot_params)
    @suggeriti = current_account.libri.potenziali_fascicoli_di(@libro).order(:titolo).limit(20)
  end

  def destroy
    @pivot = @libro.confezione_righe.find(params[:id])
    @pivot.destroy!
    @suggeriti = current_account.libri.potenziali_fascicoli_di(@libro).order(:titolo).limit(20)
  end

  private

  def set_libro
    @libro = current_account.libri.friendly.find(params[:libro_id])
  end

  def pivot_params
    params.require(:confezione_riga).permit(:fascicolo_id)
  end
end
