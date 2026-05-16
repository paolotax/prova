class BolleVisione::RigheController < BolleVisione::BaseController
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
    if params[:esplodi].present?
      @riga.esplodi_in_fascicoli!
      redirect_to @bolla_visione and return
    elsif params[:toggle_classe_id].present?
      toggle_consegna!(:classe_id, params[:toggle_classe_id])
    elsif params[:toggle_persona_id].present?
      toggle_consegna!(:persona_id, params[:toggle_persona_id])
    else
      @riga.update!(riga_params)
    end

    respond_to do |format|
      format.turbo_stream do
        scuola = @bolla_visione.scuola
        targets = risolvi_targets(@riga.libro_id)
        classi_per_anno = scuola.classi.order(:anno_corso, :sezione).group_by(&:anno_corso)
        classi = classi_per_anno.values_at(*targets).compact.flatten
        persone = classi.any? ? Persona.docente.joins(:classi).where(classi: { id: classi.map(&:id) }).distinct.order(:cognome) : Persona.none

        render turbo_stream: [
          turbo_stream.replace(@riga,
            partial: "bolla_visione_righe/bolla_visione_riga",
            locals: { riga: @riga, classi: classi, persone: persone }),
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

  # Risolve i classi_target per un libro presente in bolla: prima cerca direttamente
  # nella collana, poi (per i fascicoli esplosi) risale la catena fascicolo→confezione.
  def risolvi_targets(libro_id)
    target_per_libro = @bolla_visione.collana.collana_libri.pluck(:libro_id, :classi_target).to_h
    return target_per_libro[libro_id].to_s.split(",").map(&:strip) if target_per_libro.key?(libro_id)

    queue = [libro_id]
    visited = { libro_id => true }
    while (current = queue.shift)
      parents = ConfezioneRiga.where(fascicolo_id: current).pluck(:confezione_id)
      if (mapped = parents.find { |p| target_per_libro.key?(p) })
        return target_per_libro[mapped].to_s.split(",").map(&:strip)
      end
      parents.each { |p| next if visited[p]; visited[p] = true; queue << p }
    end
    []
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
