class BolleVisioneController < ApplicationController
  before_action :authenticate_user!
  before_action :set_tappa, only: [:new, :create]
  before_action :set_bolla_visione, only: [:show, :destroy, :rigenera]

  def index
    @bolle_visione = Current.account.bolle_visione.includes(:scuola, :collana).ordered
  end

  def new
    # Collana: da param (cambio dinamico) o dal primo giro della tappa
    collana = if params[:collana_id].present?
      Current.account.collane.find_by(id: params[:collana_id])
    else
      @tappa.giri.first&.collana
    end

    @bolla_visione = BollaVisione.new(
      scuola: @tappa.tappable,
      tappa: @tappa,
      data_bolla: @tappa.data_tappa,
      collana: collana
    )
    @collane = Current.account.collane.ordered
    @scuola = @tappa.tappable
    load_target_e_classi(collana)
  end

  def create
    @bolla_visione = Current.account.bolle_visione.build(bolla_visione_params)
    @bolla_visione.user = current_user
    @bolla_visione.scuola = @tappa.tappable
    @bolla_visione.tappa = @tappa

    # Crea o assegna persona inline
    assign_or_create_contatto

    if @bolla_visione.save
      target_filter = params[:target_ids].to_a.reject(&:blank?)
      @bolla_visione.crea_righe_da_collana!(target_filter: target_filter)
      redirect_to bolla_visione_path(@bolla_visione)
    else
      @collane = Current.account.collane.ordered
      @scuola = @tappa.tappable
      load_target_e_classi(@bolla_visione.collana)
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    @bolla_visione.destroy!
    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.remove(@bolla_visione) }
      format.html { redirect_to @bolla_visione.tappa ? tappa_path(@bolla_visione.tappa) : bolle_visione_path }
    end
  end

  def rigenera
    @bolla_visione.bolla_visione_righe.destroy_all
    @bolla_visione.crea_righe_da_collana!
    redirect_to bolla_visione_path(@bolla_visione), notice: "Bolla rigenerata con #{@bolla_visione.bolla_visione_righe.count} righe"
  end

  def show
    @righe = @bolla_visione.bolla_visione_righe.includes(libro: :editore).order(:position)
    # Mappa libro_id → attributi dalla collana
    collana_libri = @bolla_visione.collana.collana_libri.order(:position)
    @target_per_libro = collana_libri.pluck(:libro_id, :classi_target).to_h
    @gruppo_per_libro = collana_libri.pluck(:libro_id, :gruppo).to_h

    # Propaga gruppo/target dai confezione ai fascicoli presenti in bolla ma non in collana,
    # risalendo la catena (scatole cinesi). Un fascicolo puo' avere piu' confezioni padre:
    # cerco quella (diretta o transitiva) presente nella collana.
    (@righe.map(&:libro_id).uniq - @gruppo_per_libro.keys).each do |orfano|
      visited = { orfano => true }
      queue = [orfano]
      mapped_parent = nil
      while (current = queue.shift)
        parents = ConfezioneRiga.where(fascicolo_id: current).pluck(:confezione_id)
        if (direct = parents.find { |p| @gruppo_per_libro.key?(p) })
          mapped_parent = direct
          break
        end
        parents.each do |p|
          next if visited[p]
          visited[p] = true
          queue << p
        end
      end
      if mapped_parent
        @gruppo_per_libro[orfano] = @gruppo_per_libro[mapped_parent]
        @target_per_libro[orfano] ||= @target_per_libro[mapped_parent]
      end
    end

    scuola = @bolla_visione.scuola
    @classi_per_anno = scuola.classi.order(:anno_corso, :sezione).group_by(&:anno_corso)
    @persone = scuola.persone.order(:cognome)

    respond_to do |format|
      format.html
      format.pdf do
        pdf = BollaVisionePdf.new(@bolla_visione, view_context)
        send_data pdf.render,
          filename: "BV-#{@bolla_visione.numero}_#{@bolla_visione.scuola.denominazione.parameterize}.pdf",
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

  def load_target_e_classi(collana)
    if collana
      # Estrai tutti i tag unici dai classi_target della collana
      @target_disponibili = collana.collana_libri
        .where.not(classi_target: [nil, ""])
        .pluck(:classi_target)
        .flat_map { |t| t.split(",").map(&:strip) }
        .uniq
        .sort
    else
      @target_disponibili = []
    end
    @classi = @scuola.classi.order(:anno_corso, :sezione) if @scuola.respond_to?(:classi)
  end

  def assign_or_create_contatto
    persona_params = params[:persona]
    return unless persona_params.present?

    scuola = @tappa.tappable

    # Se c'è un id, è una persona esistente selezionata dal combobox
    if persona_params[:id].present?
      @bolla_visione.contatto = scuola.persone.find_by(id: persona_params[:id])
      return
    end

    # Crea persona se c'è almeno un campo compilato (nome, cognome, classe, materia, etc.)
    has_any_data = %i[cognome nome email cellulare materia].any? { |k| persona_params[k].present? } ||
                   persona_params[:classe_ids].to_a.reject(&:blank?).any?
    return unless has_any_data

    cognome = persona_params[:cognome].presence
    nome = persona_params[:nome].presence
    cognome = "Da compilare" if cognome.blank? && nome.blank?

    persona = scuola.persone.create!(
      cognome: cognome,
      nome: nome,
      email: persona_params[:email],
      cellulare: persona_params[:cellulare],
      ruolo: persona_params[:ruolo].presence || :docente,
      account: Current.account
    )

    # Assegna classi se selezionate
    classe_ids = persona_params[:classe_ids].to_a.reject(&:blank?)
    materia = persona_params[:materia]
    if classe_ids.any?
      scuola.classi.where(id: classe_ids).each do |classe|
        persona.persona_classi.create(classe: classe, materia: materia)
      end
    end

    @bolla_visione.contatto = persona
  end

  def bolla_visione_params
    params.require(:bolla_visione).permit(:collana_id, :contatto_id, :data_bolla, :note)
  end
end
