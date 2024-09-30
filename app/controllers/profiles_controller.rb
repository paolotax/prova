class ProfilesController < ApplicationController
  
  include Wicked::Wizard

  before_action :authenticate_user!  
  #before_action :set_profile, only: %i[ show edit update destroy ]

  steps :personal, :address, :bank

  def show
    @user = current_user
    @profile = @user.profile || @user.build_profile
    render_wizard
  end

  def create
    @user = current_user
    @profile = @user.profile || @user.build_profile
    redirect_to wizard_path(steps.first, profile_id: @profile.id)
  end

  def update
    @user = current_user
    @profile = @user.profile || @user.build_profile
    @profile.update(profile_params)
    render_wizard @profile
  end

  private

    def profile_params
      params.require(:profile).permit(:user_id, :nome, :cognome, :ragione_sociale, :indirizzo, :cap, :citta, :cellulare, :email, :iban, :nome_banca)
    end
end
