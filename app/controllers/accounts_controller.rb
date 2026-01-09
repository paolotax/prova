class AccountsController < ApplicationController
  layout "auth", only: [:index, :new, :create]

  skip_before_action :set_current_account_from_url, only: [:index, :new, :create]
  skip_before_action :ensure_account_member, only: [:index, :new, :create]

  def index
    @accounts = current_user.accounts.order(:name)

    # Se l'utente ha un solo account, redirect diretto
    if @accounts.one?
      redirect_to account_root_path(@accounts.first)
    end
  end

  def new
    @account = Account.new
  end

  def create
    @account = Account.new(account_params)

    if @account.save
      # L'utente diventa owner del nuovo account
      @account.add_member(current_user, role: :owner)
      redirect_to account_root_path(@account), notice: "Account '#{@account.name}' creato con successo"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    redirect_to account_root_path(Current.account)
  end

  private

  def account_params
    params.require(:account).permit(:name)
  end
end
