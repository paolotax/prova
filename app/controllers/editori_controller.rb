class EditoriController < ApplicationController
  
  before_action :authenticate_user! 
  before_action :set_editore, only: %i[ show edit update destroy ]

  def index
    @editori = Editore.all
  end

  def show
  end

  def new
    @editore = Editore.new
  end

  def edit
  end

  def create
    @editore = Editore.new(editore_params)

    respond_to do |format|
      if @editore.save
        format.html { redirect_to editore_url(@editore), notice: "Editore creato." }
        format.json { render :show, status: :created, location: @editore }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @editore.errors, status: :unprocessable_entity }
      end
    end
  end

  def update
    respond_to do |format|
      if @editore.update(editore_params)
        format.html { redirect_to editore_url(@editore), notice: "Editore modificato." }
        format.json { render :show, status: :ok, location: @editore }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @editore.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @editore.destroy!

    respond_to do |format|
      format.html { redirect_to editori_url, alert: "Editore eliminato." }
      format.json { head :no_content }
    end
  end

  private

    def set_editore
      @editore = Editore.find(params[:id])
    end

    def editore_params
      params.require(:editore).permit(:editore, :gruppo)
    end
end
