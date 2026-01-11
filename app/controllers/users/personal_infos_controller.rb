class Users::PersonalInfosController < ApplicationController
  before_action :authenticate_user!
  before_action :set_personal_info

  def show
    # @personal_info can be nil - the view handles this case
  end

  def new
    @personal_info = Current.user.build_personal_info
  end

  def create
    @personal_info = Current.user.build_personal_info(personal_info_params)

    if @personal_info.save
      redirect_to user_personal_info_path(Current.user), notice: "Informazioni personali create."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    if @personal_info.nil?
      redirect_to new_user_personal_info_path(Current.user)
    end
  end

  def update
    if @personal_info.nil?
      redirect_to new_user_personal_info_path(Current.user), alert: "Devi prima creare le informazioni personali."
      return
    end

    if @personal_info.update(personal_info_params)
      redirect_to user_personal_info_path(Current.user), notice: "Informazioni personali aggiornate.", status: :see_other
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_personal_info
    @personal_info = Current.user.personal_info
  end

  def personal_info_params
    params.require(:personal_info).permit(:nome, :cognome, :cellulare, :email_personale, :navigator)
  end
end
