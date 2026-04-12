class CollanaLibriController < ApplicationController
  before_action :authenticate_user!
  before_action :set_collana

  def create
    @collana_libro = @collana.collana_libri.build(collana_libro_params)
    @collana_libro.account = Current.account

    if @collana_libro.save
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to @collana }
      end
    else
      redirect_to @collana, alert: "Libro già presente nella collana"
    end
  end

  def update
    @collana_libro = @collana.collana_libri.find(params[:id])
    @collana_libro.update!(collana_libro_params)

    respond_to do |format|
      # No re-render: i valori sono già nel DOM (preserva focus durante editing inline)
      format.turbo_stream { head :no_content }
      format.html { redirect_to @collana }
    end
  end

  def destroy
    @collana_libro = @collana.collana_libri.find(params[:id])
    @collana_libro.destroy!

    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.remove(@collana_libro) }
      format.html { redirect_to @collana }
    end
  end

  private

  def set_collana
    @collana = Current.account.collane.find(params[:collana_id])
  end

  def collana_libro_params
    params.require(:collana_libro).permit(:libro_id, :classi_target, :gruppo, :position)
  end
end
