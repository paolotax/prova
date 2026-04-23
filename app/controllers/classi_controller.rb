class ClassiController < ApplicationController

  before_action :authenticate_user!
  before_action :set_classe, only: %i[ show ]

  def index
    scope = Classe.search_scope(
      combinazione: params[:combinazione],
      provincia: params[:provincia],
      comune: params[:comune],
      tipo_scuola: params[:tipo_scuola],
      anno_corso: params[:anno_corso]
    )
    @total = scope.count
    @classi = scope.offset((params[:offset] || 0).to_i).limit((params[:limit] || 50).to_i.clamp(1, 200))
    @group_by_scuola = ActiveModel::Type::Boolean.new.cast(params[:group_by_scuola])

    respond_to { |format| format.json }
  end

  def show
    # Redirect to nested scuola/classe route if scuola exists
    if @classe.scuola.present?
      redirect_to scuola_classe_path(@classe.scuola, @classe)
    end
  end

  private

    def set_classe
      @classe = Current.account.classi.find(params[:id])
    end

end
