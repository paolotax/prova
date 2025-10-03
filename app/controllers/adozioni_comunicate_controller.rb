class AdozioniComunicateController < ApplicationController
  before_action :authenticate_user!
  before_action :set_adozione_comunicata, only: [:show, :edit, :update, :destroy]
  
  def index
    @adozioni_comunicate = AdozioneComunicata.mie_adozioni_comunicate
                                            .includes(:import_adozione)
                                            .order(:editore, :descrizione_scuola, :classe, :sezione)
    
    # Filtri
    @adozioni_comunicate = @adozioni_comunicate.per_editore(params[:editore]) if params[:editore].present?
    @adozioni_comunicate = @adozioni_comunicate.per_scuola(params[:scuola]) if params[:scuola].present?
    @adozioni_comunicate = @adozioni_comunicate.per_classe(params[:classe]) if params[:classe].present?
    
    # Filtro per corrispondenze
    case params[:corrispondenza]
    when 'con'
      @adozioni_comunicate = @adozioni_comunicate.con_corrispondenza
    when 'senza'
      @adozioni_comunicate = @adozioni_comunicate.senza_corrispondenza
    end
    
    # Statistiche
    @statistiche_editore = AdozioneComunicata.statistiche_per_editore(current_user)
    @statistiche_scuola = AdozioneComunicata.statistiche_per_scuola(current_user)
    @statistiche_classe = AdozioneComunicata.statistiche_per_classe(current_user)
    
    # Totale alunni
    @totale_alunni = @adozioni_comunicate.sum(:alunni)
    @totale_corrispondenze = @adozioni_comunicate.con_corrispondenza.count
    
    # Opzioni per i filtri
    @editori_options = AdozioneComunicata.mie_adozioni_comunicate
                                        .distinct
                                        .pluck(:editore)
                                        .compact
                                        .sort
    
    @scuole_options = AdozioneComunicata.mie_adozioni_comunicate
                                       .distinct
                                       .pluck(:cod_ministeriale, :descrizione_scuola)
                                       .map { |cod, desc| ["#{desc} (#{cod})", cod] }
    
    @classi_options = AdozioneComunicata.mie_adozioni_comunicate
                                       .distinct
                                       .pluck(:classe)
                                       .compact
                                       .sort
  end
  
  def show
    @differenze = @adozione_comunicata.differenze_con_import_adozione if @adozione_comunicata.corrispondenza_trovata?
  end
  
  def new
    @adozione_comunicata = AdozioneComunicata.new
  end
  
  def create
    @adozione_comunicata = AdozioneComunicata.new(adozione_comunicata_params)
    @adozione_comunicata.user = current_user
    
    if @adozione_comunicata.save
      # Cerca automaticamente la corrispondenza
      @adozione_comunicata.trova_corrispondenza_import_adozione
      
      redirect_to @adozione_comunicata, notice: 'Adozione comunicata creata con successo.'
    else
      render :new
    end
  end
  
  def edit
  end
  
  def update
    if @adozione_comunicata.update(adozione_comunicata_params)
      # Aggiorna la corrispondenza
      @adozione_comunicata.trova_corrispondenza_import_adozione
      
      redirect_to @adozione_comunicata, notice: 'Adozione comunicata aggiornata con successo.'
    else
      render :edit
    end
  end
  
  def destroy
    @adozione_comunicata.destroy
    redirect_to adozioni_comunicate_path, notice: 'Adozione comunicata eliminata con successo.'
  end
  
  def import
    if request.post?
      if params[:file].present?
        begin
          result = AdozioneComunicata.importa_da_excel(params[:file].path, current_user)
          
          if result[:errori] > 0
            flash[:warning] = "Importati #{result[:importati]} record nuovi, aggiornati #{result[:aggiornati]} record esistenti con #{result[:errori]} errori."
          else
            flash[:success] = "Importati #{result[:importati]} record nuovi, aggiornati #{result[:aggiornati]} record esistenti con successo."
          end
          
          redirect_to adozioni_comunicate_path
        rescue => e
          flash[:error] = "Errore durante l'importazione: #{e.message}"
          render :import
        end
      else
        flash[:error] = "Seleziona un file Excel."
        render :import
      end
    end
  end
  
  def confronto
    @adozioni_comunicate = AdozioneComunicata.mie_adozioni_comunicate.includes(:import_adozione)
    
    # Statistiche del confronto
    @totale_comunicate = @adozioni_comunicate.count
    @con_corrispondenza = @adozioni_comunicate.con_corrispondenza.count
    @senza_corrispondenza = @adozioni_comunicate.senza_corrispondenza.count
    
    @totale_alunni_comunicate = @adozioni_comunicate.sum(:alunni)
    @totale_alunni_corrispondenza = @adozioni_comunicate.con_corrispondenza.sum(:alunni)
    
    # Raggruppa per editore usando pluck per evitare problemi con select
    editori_stats = @adozioni_comunicate.group_by(&:editore).map do |editore, adozioni|
      {
        editore: editore,
        totale_comunicate: adozioni.count,
        totale_alunni: adozioni.sum(&:alunni),
        con_corrispondenza: adozioni.count { |a| a.import_adozione_id.present? },
        alunni_senza_corrispondenza: adozioni.select { |a| a.import_adozione_id.nil? }.sum(&:alunni)
      }
    end
    @confronto_per_editore = editori_stats
    
    # Raggruppa per scuola usando pluck per evitare problemi con select
    scuole_stats = @adozioni_comunicate.group_by { |a| [a.cod_ministeriale, a.descrizione_scuola] }.map do |(cod, desc), adozioni|
      {
        cod_ministeriale: cod,
        descrizione_scuola: desc,
        totale_comunicate: adozioni.count,
        totale_alunni: adozioni.sum(&:alunni),
        con_corrispondenza: adozioni.count { |a| a.import_adozione_id.present? },
        alunni_senza_corrispondenza: adozioni.select { |a| a.import_adozione_id.nil? }.sum(&:alunni)
      }
    end
    @confronto_per_scuola = scuole_stats.sort_by { |s| s[:descrizione_scuola] }
    
    # Adozioni comunicate senza corrispondenza (dettaglio)
    @senza_corrispondenza_dettaglio = @adozioni_comunicate
      .senza_corrispondenza
      .order(:editore, :descrizione_scuola, :classe, :sezione)
    
    # Trova le mie_adozioni che non hanno corrispondenza nelle adozioni comunicate
    # Filtra solo per le scuole della mia zona (user_scuole)
    mie_scuole_codes = current_user.user_scuole.joins(:import_scuola).pluck('import_scuole.CODICESCUOLA').compact
    mie_adozioni_ean = @adozioni_comunicate.con_corrispondenza.pluck(:ean).compact
    
    @mie_adozioni_senza_corrispondenza = ImportAdozione.mie_adozioni
      .where.not(CODICEISBN: mie_adozioni_ean)
      .where(CODICESCUOLA: mie_scuole_codes)
      .includes(:import_scuola)
      .order(:EDITORE, :CODICESCUOLA, :ANNOCORSO, :SEZIONEANNO)
    
    # Statistiche per le mie_adozioni (solo per la mia zona)
    @totale_mie_adozioni = ImportAdozione.mie_adozioni.where(CODICESCUOLA: mie_scuole_codes).count
    @mie_adozioni_con_corrispondenza = ImportAdozione.mie_adozioni
      .where(CODICEISBN: mie_adozioni_ean)
      .where(CODICESCUOLA: mie_scuole_codes)
      .count
    @mie_adozioni_senza_corrispondenza_count = @mie_adozioni_senza_corrispondenza.count
  end
  
  def aggiorna_corrispondenze
    AdozioneComunicata.aggiorna_corrispondenze(current_user)
    redirect_to confronto_adozioni_comunicate_path, notice: 'Corrispondenze aggiornate con successo.'
  end
  
  def export_excel
    @adozioni_comunicate = AdozioneComunicata.mie_adozioni_comunicate.includes(:import_adozione)
    
    # Applica gli stessi filtri della view index
    @adozioni_comunicate = @adozioni_comunicate.per_editore(params[:editore]) if params[:editore].present?
    @adozioni_comunicate = @adozioni_comunicate.per_scuola(params[:scuola]) if params[:scuola].present?
    @adozioni_comunicate = @adozioni_comunicate.per_classe(params[:classe]) if params[:classe].present?
    
    # Filtro per corrispondenze
    case params[:corrispondenza]
    when 'con'
      @adozioni_comunicate = @adozioni_comunicate.con_corrispondenza
    when 'senza'
      @adozioni_comunicate = @adozioni_comunicate.senza_corrispondenza
    end
    
    respond_to do |format|
      format.xlsx
    end
  end
  
  private
  
  def set_adozione_comunicata
    # Se params[:id] è una delle azioni collection, non cercare un record
    collection_actions = %w[import confronto aggiorna_corrispondenze export_excel]
    if collection_actions.include?(params[:id])
      return
    end
    
    @adozione_comunicata = AdozioneComunicata.mie_adozioni_comunicate.find(params[:id])
  end
  
  def adozione_comunicata_params
    params.require(:adozione_comunicata).permit(
      :cod_agente, :anno_scolastico, :cod_ministeriale, :descrizione_scuola,
      :indirizzo, :cap, :comune, :provincia, :cod_scuola, :editore,
      :ean, :titolo, :classe, :sezione, :alunni
    )
  end
end
