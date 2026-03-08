class CollaneController < ApplicationController
  before_action :authenticate_user!
  before_action :set_collana, only: [:show, :edit, :update, :destroy]

  def index
    @collane = Current.account.collane.includes(:collana_libri).ordered
  end

  def show
  end

  def new
    @collana = Collana.new
  end

  def create
    @collana = Current.account.collane.build(collana_params)
    @collana.user = current_user

    if @collana.save
      redirect_to @collana
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @collana.update(collana_params)
      redirect_to @collana
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @collana.destroy!
    redirect_to collane_path
  end

  private

  def set_collana
    @collana = Current.account.collane.find(params[:id])
  end

  def collana_params
    params.require(:collana).permit(:nome)
  end
end
