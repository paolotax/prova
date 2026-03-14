class BollaVisioneRigheController < ApplicationController
  before_action :authenticate_user!
  before_action :set_bolla_visione
  before_action :set_riga, only: [:update, :destroy]

  def create
    libro = Libro.find(params[:bolla_visione_riga][:libro_id])
    @riga = @bolla_visione.bolla_visione_righe.create!(
      libro: libro,
      classi_target: params[:bolla_visione_riga][:classi_target],
      account: Current.account
    )

    respond_to do |format|
      format.turbo_stream do
        scuola = @bolla_visione.scuola
        classi = scuola.classi.where(anno_corso: @riga.classi_target.to_s.split(",").map(&:strip)).order(:anno_corso, :sezione)
        render turbo_stream: [
          turbo_stream.before("bolla_visione_righe_form",
            partial: "bolla_visione_righe/bolla_visione_riga",
            locals: { riga: @riga, classi: classi, persone: scuola.persone.order(:cognome) }),
          turbo_stream_totale
        ]
      end
      format.html { redirect_to @bolla_visione }
    end
  end

  def update
    if params[:toggle_classe_id].present?
      toggle_consegna!(:classe_id, params[:toggle_classe_id])
    elsif params[:toggle_persona_id].present?
      toggle_consegna!(:persona_id, params[:toggle_persona_id])
    else
      @riga.update!(riga_params)
    end

    respond_to do |format|
      format.turbo_stream do
        scuola = @bolla_visione.scuola
        render turbo_stream: [
          turbo_stream.replace(@riga,
            partial: "bolla_visione_righe/bolla_visione_riga",
            locals: {
              riga: @riga,
              classi: scuola.classi.where(anno_corso: @riga.classi_target.to_s.split(",").map(&:strip)).order(:anno_corso, :sezione),
              persone: scuola.persone.order(:cognome)
            }),
          turbo_stream_totale
        ]
      end
      format.html { redirect_to @bolla_visione }
    end
  end

  def destroy
    @riga.destroy!

    respond_to do |format|
      format.turbo_stream { render turbo_stream: [turbo_stream.remove(@riga), turbo_stream_totale] }
      format.html { redirect_to @bolla_visione }
    end
  end

  private

  def set_bolla_visione
    @bolla_visione = Current.account.bolle_visione.find(params[:bolla_visione_id])
  end

  def set_riga
    @riga = @bolla_visione.bolla_visione_righe.find(params[:id])
  end

  def riga_params
    params.require(:bolla_visione_riga).permit(:quantita, :classi_target)
  end

  def turbo_stream_totale
    totale = @bolla_visione.bolla_visione_righe.sum(:quantita)
    turbo_stream.replace("bolla_visione_totale",
      html: %(<div id="bolla_visione_totale" class="flex justify-space-between align-center margin-block-start pad-block txt-medium font-weight-black" style="border-block-start: 2px solid var(--color-ink-light);"><span>Totale copie</span><span>#{totale}</span></div>).html_safe)
  end

  def toggle_consegna!(key, value)
    consegna = @riga.consegna || {}
    current = Array(consegna[key.to_s])

    if current.include?(value)
      current.delete(value)
    else
      current << value
    end

    consegna[key.to_s] = current.compact_blank
    consegna.delete(key.to_s) if consegna[key.to_s].empty?
    @riga.update!(consegna: consegna)
  end
end
