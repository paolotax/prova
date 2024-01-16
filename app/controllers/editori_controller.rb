class EditoriController < ApplicationController
  before_action :set_editore, only: %i[ show edit update destroy ]

  # GET /editori or /editori.json
  def index
    @editori = Editore.all
  end

  # GET /editori/1 or /editori/1.json
  def show
  end

  # GET /editori/new
  def new
    @editore = Editore.new
  end

  # GET /editori/1/edit
  def edit
  end

  # POST /editori or /editori.json
  def create
    @editore = Editore.new(editore_params)

    respond_to do |format|
      if @editore.save
        format.html { redirect_to editore_url(@editore), notice: "Editore was successfully created." }
        format.json { render :show, status: :created, location: @editore }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @editore.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /editori/1 or /editori/1.json
  def update
    respond_to do |format|
      if @editore.update(editore_params)
        format.html { redirect_to editore_url(@editore), notice: "Editore was successfully updated." }
        format.json { render :show, status: :ok, location: @editore }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @editore.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /editori/1 or /editori/1.json
  def destroy
    @editore.destroy!

    respond_to do |format|
      format.html { redirect_to editori_url, notice: "Editore was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_editore
      @editore = Editore.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def editore_params
      params.require(:editore).permit(:editore, :gruppo)
    end
end
