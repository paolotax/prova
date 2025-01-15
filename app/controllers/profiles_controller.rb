class ProfilesController < ApplicationController
  
  before_action :authenticate_user!  
  before_action :set_profile, only: %i[ show edit update destroy ]

  def index
    @profiles = authorize Profile.all
  end

  def new  
    @profile = current_user.profile || current_user.build_profile
    authorize @profile
    @profile.save! validate: false
    
    redirect_to profile_step_path(@profile, Profile.form_steps.keys.first)
  end
  
  def show
  end

  def get_user_profile
    @profile = current_user.profile
    authorize @profile
    redirect_to current_user
  end

  def edit  
  end

  def create    
  end

  def update
  end

  def destroy
  end

  private

    def set_profile
      @profile = authorize Profile.find(params[:id])
    end

    def profile_params
      params.require(:profile).permit(:user_id, :nome, :cognome, :ragione_sociale, :indirizzo, :cap, :citta, :cellulare, :email, :iban, :nome_banca)
    end
end
