class Libri::CopertineController < ApplicationController
  before_action :set_libro

  def show
    if (thumbnail = @libro.copertina_thumbnail)
      redirect_to url_for(thumbnail), allow_other_host: true
    elsif stale? @libro, cache_control: { max_age: 30.minutes, stale_while_revalidate: 1.week }
      render formats: :svg
    end
  end

  def destroy
    @libro.edizione_titolo&.copertina&.purge
    @libro.copertina.purge if @libro.copertina.attached?
    @libro.touch
    redirect_to edit_libro_path(@libro)
  end

  private
    def set_libro
      @libro = Current.account.libri.friendly.find(params[:libro_id])
    end
end
