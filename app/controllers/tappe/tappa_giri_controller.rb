class Tappe::TappaGiriController < ApplicationController
  include ActionView::RecordIdentifier
  before_action :authenticate_user!
  before_action :set_tappa

  def index
    new
    render :new
  end

  def new
    @tagged_with = @tappa.giri
    @giri = current_user.giri.where.not(id: @tagged_with.select(:id)).order(created_at: :desc)
  end

  def create
    titolo = params[:giro_titolo].to_s.strip
    return head :unprocessable_entity if titolo.blank?

    giro = current_user.giri.find_or_create_by!(titolo: titolo) do |g|
      g.account = Current.account
    end

    if @tappa.giri.include?(giro)
      @tappa.tappa_giri.find_by(giro: giro)&.destroy
    else
      @tappa.tappa_giri.create!(giro: giro)
    end

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          dom_id(@tappa, :tags),
          partial: "tappe/display/perma/tags",
          locals: { tappa: @tappa.reload }
        )
      end
    end
  end

  private

  def set_tappa
    @tappa = current_user.tappe.find(params[:tappa_id])
  end
end
