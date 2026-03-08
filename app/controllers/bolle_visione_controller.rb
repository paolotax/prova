class BolleVisioneController < ApplicationController
  before_action :authenticate_user!
  before_action :set_tappa, only: [:new, :create]
  before_action :set_bolla_visione, only: [:show]

  def index
    @bolle_visione = Current.account.bolle_visione.includes(:scuola, :collana).ordered
  end

  def new
    @bolla_visione = BollaVisione.new(
      scuola: @tappa.tappable,
      tappa: @tappa,
      data_bolla: Date.current
    )
    @collane = Current.account.collane.ordered
    @referenti = @tappa.tappable.persone.per_ruolo(:referente) if @tappa.tappable.respond_to?(:persone)
  end

  def create
    @bolla_visione = Current.account.bolle_visione.build(bolla_visione_params)
    @bolla_visione.user = current_user
    @bolla_visione.scuola = @tappa.tappable
    @bolla_visione.tappa = @tappa

    if @bolla_visione.save
      @bolla_visione.crea_righe_da_collana!
      redirect_to bolla_visione_path(@bolla_visione)
    else
      @collane = Current.account.collane.ordered
      @referenti = @tappa.tappable.persone.per_ruolo(:referente) if @tappa.tappable.respond_to?(:persone)
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @righe = @bolla_visione.bolla_visione_righe.includes(libro: :editore)
              .joins(:libro).order("libri.disciplina, libri.titolo")
    # Mappa libro_id → classi_target dalla collana
    @target_per_libro = @bolla_visione.collana.collana_libri.pluck(:libro_id, :classi_target).to_h
    scuola = @bolla_visione.scuola
    @classi_per_anno = scuola.classi.order(:anno_corso, :sezione).group_by(&:anno_corso)
    @persone = scuola.persone.order(:cognome)

    respond_to do |format|
      format.html
      format.pdf do
        pdf = BollaVisionePdf.new(@bolla_visione, view_context)
        send_data pdf.render,
          filename: "bolla_visione_#{@bolla_visione.numero}.pdf",
          type: "application/pdf",
          disposition: "inline"
      end
    end
  end

  private

  def set_tappa
    @tappa = current_user.tappe.find(params[:tappa_id])
  end

  def set_bolla_visione
    @bolla_visione = Current.account.bolle_visione.find(params[:id])
  end

  def bolla_visione_params
    params.require(:bolla_visione).permit(:collana_id, :referente_id, :data_bolla, :note)
  end
end
