class ControlloAdozioniController < ApplicationController
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
    redirect_to adozione_comunicate_index_path, notice: 'Adozione comunicata eliminata con successo.'
  end
  
  def import
    if request.post?
      if params[:file].present?
        begin
          result = AdozioneComunicata.importa_da_excel(params[:file].path, current_user)
          
          if result[:errori] > 0
            flash[:warning] = "Importati #{result[:importati]} record con #{result[:errori]} errori."
          else
            flash[:success] = "Importati #{result[:importati]} record con successo."
          end
          
          redirect_to adozione_comunicate_index_path
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
    
    # Raggruppa per editore
    @confronto_per_editore = @adozioni_comunicate
      .group(:editore)
      .select(:editore)
      .select('COUNT(*) as totale_comunicate')
      .select('SUM(alunni) as totale_alunni')
      .select('COUNT(import_adozione_id) as con_corrispondenza')
      .select('SUM(CASE WHEN import_adozione_id IS NULL THEN alunni ELSE 0 END) as alunni_senza_corrispondenza')
    
    # Raggruppa per scuola
    @confronto_per_scuola = @adozioni_comunicate
      .group(:cod_ministeriale, :descrizione_scuola)
      .select(:cod_ministeriale, :descrizione_scuola)
      .select('COUNT(*) as totale_comunicate')
      .select('SUM(alunni) as totale_alunni')
      .select('COUNT(import_adozione_id) as con_corrispondenza')
      .select('SUM(CASE WHEN import_adozione_id IS NULL THEN alunni ELSE 0 END) as alunni_senza_corrispondenza')
      .order(:descrizione_scuola)
    
    # Adozioni senza corrispondenza (dettaglio)
    @senza_corrispondenza_dettaglio = @adozioni_comunicate
      .senza_corrispondenza
      .order(:editore, :descrizione_scuola, :classe, :sezione)
  end
  
  def aggiorna_corrispondenze
    AdozioneComunicata.aggiorna_corrispondenze(current_user)
    redirect_to confronto_adozione_comunicate_index_path, notice: 'Corrispondenze aggiornate con successo.'
  end
  
  def export_excel
    @adozioni_comunicate = AdozioneComunicata.mie_adozioni_comunicate.includes(:import_adozione)
    
    respond_to do |format|
      format.xlsx {
        response.headers['Content-Disposition'] = "attachment; filename=adozioni_comunicate_#{Date.current.strftime('%Y%m%d')}.xlsx"
      }
    end
  end
  
  private
  
  def set_adozione_comunicata
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
