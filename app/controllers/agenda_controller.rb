class AgendaController < ApplicationController

  before_action :authenticate_user!
  
  def index
    @giorno = params[:giorno]&.to_date || Date.today
    weeks_count = (params[:weeks] || 5).to_i
    direction = params[:direction]

    @settimane = build_weeks(@giorno, weeks_count, direction)
    start_date = @settimane.first.first
    end_date = @settimane.last.last
    @tappe_per_giorno = current_user.tappe
      .where(data_tappa: start_date..end_date)
      .includes(:tappable, :giri)
      .group_by(&:data_tappa)

    respond_to do |format|
      format.html
      format.turbo_stream do
        target_action = direction == "prepend" ? :prepend : :append
        render turbo_stream: turbo_stream.send(target_action, "weeks-container",
          partial: "agenda/weeks", locals: { settimane: @settimane, tappe_per_giorno: @tappe_per_giorno })
      end
    end
  end

  def planner
    tappe = current_user.tappe
      .da_programmare
      .where(tappable_type: "Scuola")
      .includes(:giri)
      .preload(:tappable)

    if params[:giro_id].present?
      tappe = tappe.joins(:giri).where(giri: { id: params[:giro_id] }).distinct
    end

    tappe_per_area = tappe
      .group_by { |t| t.tappable.area.presence || "Senza area" }
      .sort_by { |area, _| area == "Senza area" ? "zzz" : area }
      .map { |area, area_tappe|
        direzioni = area_tappe
          .group_by { |t| t.tappable.direzione || t.tappable }
          .sort_by { |dir, _| dir.respond_to?(:denominazione) ? dir.denominazione : "" }
        [area, direzioni]
      }

    giri = current_user.giri.order(created_at: :desc)

    render partial: "agenda/planner", locals: {
      tappe_per_area: tappe_per_area,
      giri: giri,
      total_count: tappe.size,
      selected_giro_id: params[:giro_id]
    }
  end

  def show
    @giorno = params[:giorno] ? Date.parse(params[:giorno]) : Date.today
    @scuole = current_account.scuole
                .where(id: current_user.tappe.del_giorno(@giorno).where(tappable_type: "Scuola").pluck(:tappable_id))
    @clienti = current_user.clienti
                .where(id: current_user.tappe.del_giorno(@giorno).where(tappable_type: "Cliente").pluck(:tappable_id))

    @tappe = current_user.tappe.del_giorno(@giorno).includes(:tappable, :giri).order(:position)
    load_giorno_entries
  end

  def mappa 
    @giorno = params[:giorno] ? Date.parse(params[:giorno]) : Date.today
    
    @tappe = current_user.tappe.del_giorno(@giorno).includes(:tappable, :giri).order(:position)

    @indirizzi = @tappe.map do |t|
      {
        latitude: t.latitude,
        longitude: t.longitude
      }
    end

    @waypoints = @tappe.map do |indirizzo|
      [
        indirizzo.longitude,
        indirizzo.latitude,
        indirizzo.tappable.denominazione,
        indirizzo.tappable.comune,
        indirizzo.tappable_type == "Scuola" ? indirizzo.tappable_id : nil
      ]
    end
  end

  def adozioni_tappe_pdf
    @giorno = params[:giorno] ? Date.parse(params[:giorno]) : Date.today
    
    # Utilizziamo la query SQL testata e funzionante
    sql = <<~SQL
      WITH sezioni_raggruppate AS (
          SELECT
              ia."TITOLO",
              ia."CODICEISBN",
              ia."EDITORE",
              ia."DISCIPLINA",
              s.denominazione AS "DENOMINAZIONESCUOLA",
              s.id as scuola_id,
              ia."ANNOCORSO",
              STRING_AGG(DISTINCT ia."SEZIONEANNO", '' ORDER BY ia."SEZIONEANNO") as sezioni_concatenate,
              COUNT(ia.id) as adozioni_per_classe
          FROM import_adozioni ia
              INNER JOIN scuole s ON ia."CODICESCUOLA" = s.codice_ministeriale AND s.account_id = $3
              INNER JOIN editori e ON ia."EDITORE" = e.editore
              INNER JOIN mandati m ON e.id = m.editore_id
              INNER JOIN tappe t ON (
                  t.tappable_type = 'Scuola'
                  AND t.tappable_id = s.id
                  AND t.data_tappa = $1
                  AND t.user_id = $2
              )
          WHERE m.user_id = $2 AND ia."DAACQUIST" = 'Si'
          GROUP BY
              ia."TITOLO", ia."CODICEISBN", ia."EDITORE", ia."DISCIPLINA",
              s.denominazione, s.id, ia."ANNOCORSO"
      ), saggi_per_adozione AS (
          SELECT
              ia."TITOLO",
              ia."CODICEISBN",
              ia."EDITORE",
              ia."DISCIPLINA",
              s.denominazione AS "DENOMINAZIONESCUOLA",
              ia."ANNOCORSO",
              ia."SEZIONEANNO",
              COUNT(a.id) as numero_saggi
          FROM appunti a
              INNER JOIN import_adozioni ia ON a.import_adozione_id = ia.id
              INNER JOIN scuole s ON ia."CODICESCUOLA" = s.codice_ministeriale AND s.account_id = $3
              INNER JOIN tappe t ON (
                  t.tappable_type = 'Scuola'
                  AND t.tappable_id = s.id
                  AND t.data_tappa = $1
                  AND t.user_id = $2
              )
          WHERE a.nome = 'saggio' AND a.user_id = $2
          GROUP BY ia."TITOLO", ia."CODICEISBN", ia."EDITORE", ia."DISCIPLINA",
                   s.denominazione, ia."ANNOCORSO", ia."SEZIONEANNO"
      ), saggi_sommati AS (
          SELECT
              spa."TITOLO",
              spa."CODICEISBN",
              spa."EDITORE",
              spa."DISCIPLINA",
              spa."DENOMINAZIONESCUOLA",
              spa."ANNOCORSO",
              SUM(spa.numero_saggi) AS totale_saggi
          FROM saggi_per_adozione spa
          GROUP BY
              spa."TITOLO",
              spa."CODICEISBN",
              spa."EDITORE",
              spa."DISCIPLINA",
              spa."DENOMINAZIONESCUOLA",
              spa."ANNOCORSO"
      )
      SELECT
          SUM(sr.adozioni_per_classe) as numero_adozioni,
          sr."TITOLO" as titolo,
          sr."CODICEISBN" as codice_isbn,
          sr."EDITORE" as editore,
          sr."DISCIPLINA" as disciplina,
          STRING_AGG(DISTINCT sr."DENOMINAZIONESCUOLA", ', ') as scuole,
          STRING_AGG(DISTINCT
              CONCAT(sr."DENOMINAZIONESCUOLA", ', ', sr."ANNOCORSO", ' ', sr.sezioni_concatenate,
                     CASE
                         WHEN COALESCE(ss.totale_saggi, 0) > 0 THEN CONCAT('(', ss.totale_saggi, ')')
                         ELSE ''
                     END),
              '; ') as classi
      FROM sezioni_raggruppate sr
      LEFT JOIN saggi_sommati ss ON (
          sr."TITOLO" = ss."TITOLO"
          AND sr."CODICEISBN" = ss."CODICEISBN"
          AND sr."EDITORE" = ss."EDITORE"
          AND sr."DISCIPLINA" = ss."DISCIPLINA"
          AND sr."DENOMINAZIONESCUOLA" = ss."DENOMINAZIONESCUOLA"
          AND sr."ANNOCORSO" = ss."ANNOCORSO"
      )
      GROUP BY
          sr."TITOLO",
          sr."CODICEISBN",
          sr."EDITORE",
          sr."DISCIPLINA"
      ORDER BY
          sr."EDITORE",
          sr."DISCIPLINA",
          sr."TITOLO";
    SQL

    @adozioni = ActiveRecord::Base.connection.exec_query(
      sql,
      'AdozioniTappe',
      [
        ActiveRecord::Relation::QueryAttribute.new('data_tappa', @giorno, ActiveRecord::Type::Date.new),
        ActiveRecord::Relation::QueryAttribute.new('user_id', current_user.id, ActiveRecord::Type::Integer.new),
        ActiveRecord::Relation::QueryAttribute.new('account_id', current_account.id, ActiveRecord::Type::String.new)
      ]
    )

    respond_to do |format|
      format.pdf do
        pdf = AdozioniTappePdf.new(@adozioni, @giorno, view_context)
        send_data pdf.render, 
                  filename: "adozioni_tappe_#{@giorno.strftime('%Y-%m-%d')}.pdf",
                  type: 'application/pdf',
                  disposition: 'inline'
      end
    end
  end

  def tappe_giorno_pdf
    @giorno = params[:giorno] ? Date.parse(params[:giorno]) : Date.today
    
    # Recuperiamo le tappe del giorno con le relazioni necessarie per le note
    @tappe = current_user.tappe.del_giorno(@giorno)
                         .includes(:tappable, :giri)
                         .order(:position)
    
    # Recuperiamo gli appunti e documenti per tutte le tappe con query ottimizzate
    @appunti_per_tappa = {}
    @documenti_per_tappa = {}
    
    # Recupera tutte le scuole e clienti delle tappe
    scuole_ids = @tappe.select { |t| t.tappable_type == 'Scuola' }.map(&:tappable_id)
    clienti_ids = @tappe.select { |t| t.tappable_type == 'Cliente' }.map(&:tappable_id)
    
    # Query ottimizzata per gli appunti delle scuole
    if scuole_ids.any?
      appunti_counts = current_user.appunti
        .where(appuntabile_type: "Scuola", appuntabile_id: scuole_ids)
        .where(stato: ['da fare', 'in evidenza', 'in settimana', 'in visione', 'da pagare'])
        .where.not(nome: ['saggio', 'seguito', 'kit'])
        .group(:appuntabile_id)
        .count

      # Mappa i conteggi alle tappe corrispondenti
      @tappe.each do |tappa|
        if tappa.tappable_type == 'Scuola'
          @appunti_per_tappa[tappa.id] = appunti_counts[tappa.tappable_id] || 0
        else
          @appunti_per_tappa[tappa.id] = 0
        end
      end
    else
      @tappe.each { |tappa| @appunti_per_tappa[tappa.id] = 0 }
    end
    
    # Query ottimizzata per i documenti
    all_clientable_ids = scuole_ids + clienti_ids
    if all_clientable_ids.any?
      documenti_counts = current_user.documenti
        .left_joins(:consegna, :pagamento)
        .where(
          "(clientable_type = 'Scuola' AND clientable_id IN (?)) OR (clientable_type = 'Cliente' AND clientable_id IN (?))",
          scuole_ids, clienti_ids
        )
        .where("consegne.id IS NULL OR pagamenti.id IS NULL")
        .group(:clientable_type, :clientable_id)
        .count
      
      # Mappa i conteggi alle tappe corrispondenti
      @tappe.each do |tappa|
        key = [tappa.tappable_type, tappa.tappable_id]
        @documenti_per_tappa[tappa.id] = documenti_counts[key] || 0
      end
    else
      @tappe.each { |tappa| @documenti_per_tappa[tappa.id] = 0 }
    end

    respond_to do |format|
      format.pdf do
        pdf = TappeGiornoPdf.new(@tappe, @giorno, view_context, @appunti_per_tappa, @documenti_per_tappa)
        send_data pdf.render, 
                  filename: "tappe_#{@giorno.strftime('%Y-%m-%d')}.pdf",
                  type: 'application/pdf',
                  disposition: 'inline'
      end
    end
  end

  def fogli_scuola_tappe_pdf
    @giorno = params[:giorno] ? Date.parse(params[:giorno]) : Date.today
    tipo_stampa = params[:tipo_stampa] || 'mie_adozioni'
    con_sovrapacchi = params[:con_sovrapacchi] == 'true'
    
    # Prende le tappe del giorno (solo scuole)
    @tappe = current_user.tappe.del_giorno(@giorno)
                         .where(tappable_type: 'Scuola')
                         .includes(:tappable)
                         .order(:position)
    
    # Ottieni le scuole dalle tappe
    @scuole = @tappe.map(&:tappable).uniq

    respond_to do |format|
      format.pdf do
        pdf = FoglioScuolaPdf.new(@scuole, view: view_context, tipo_stampa: tipo_stampa, con_sovrapacchi: con_sovrapacchi)
        
        filename_suffix = tipo_stampa == 'mie_adozioni' ? '_mie_adozioni' : ''
        sovrapacchi_suffix = con_sovrapacchi ? '_con_sovrapacchi' : ''
        filename = "fogli_scuola_tappe_#{@giorno.strftime('%Y-%m-%d')}#{filename_suffix}#{sovrapacchi_suffix}.pdf"
        
        send_data pdf.render, 
                  filename: filename,
                  type: 'application/pdf',
                  disposition: 'inline'
      end
    end
  end

  def dettaglio_appunti_documenti_pdf
    @giorno = params[:giorno] ? Date.parse(params[:giorno]) : Date.today
    
    # Recuperiamo le tappe del giorno ordinate per posizione
    @tappe = current_user.tappe.del_giorno(@giorno)
                         .includes(:tappable, :giri)
                         .order(:position)
    
    # Recuperiamo gli appunti dettagliati per ogni tappa nell'ordine delle tappe
    @appunti_dettagliati = []
    @documenti_dettagliati = []
    
    @tappe.each do |tappa|
      if tappa.tappable_type == 'Scuola'
        # Appunti pendenti per questa scuola (escludendo SSK)
        appunti_scuola = current_user.appunti
          .where(appuntabile_type: "Scuola", appuntabile_id: tappa.tappable_id)
          .where(stato: ['da fare', 'in evidenza', 'in settimana', 'in visione', 'da pagare'])
          .where.not(nome: ['saggio', 'seguito', 'kit'])
          .includes(:appuntabile, :import_adozione)
          .order(:stato, :created_at)
        
        appunti_scuola.each do |appunto|
          @appunti_dettagliati << {
            tappa: tappa,
            appunto: appunto,
            posizione_tappa: tappa.position
          }
        end
        
        # Documenti pendenti per questa scuola (non consegnati O non pagati)
        documenti_scuola = current_user.documenti
          .left_joins(:consegna, :pagamento)
          .where(clientable_type: 'Scuola', clientable_id: tappa.tappable_id)
          .where("consegne.id IS NULL OR pagamenti.id IS NULL")
          .includes(:clientable, :causale)
          .order(:data_documento)
        
        documenti_scuola.each do |documento|
          @documenti_dettagliati << {
            tappa: tappa,
            documento: documento,
            posizione_tappa: tappa.position
          }
        end
        
      elsif tappa.tappable_type == 'Cliente'
        # Documenti pendenti per questo cliente (non consegnati O non pagati)
        documenti_cliente = current_user.documenti
          .left_joins(:consegna, :pagamento)
          .where(clientable_type: 'Cliente', clientable_id: tappa.tappable_id)
          .where("consegne.id IS NULL OR pagamenti.id IS NULL")
          .includes(:clientable, :causale)
          .order(:data_documento)
        
        documenti_cliente.each do |documento|
          @documenti_dettagliati << {
            tappa: tappa,
            documento: documento,
            posizione_tappa: tappa.position
          }
        end
      end
    end
    
    # Ordina tutto per posizione tappa
    @appunti_dettagliati.sort_by! { |item| item[:posizione_tappa] }
    @documenti_dettagliati.sort_by! { |item| item[:posizione_tappa] }
    
    # Calcola riassunto titoli da consegnare (documenti non consegnati)
    @riassunto_titoli = {}
    @documenti_dettagliati.each do |item|
      documento = item[:documento]
      next if documento.consegnato? # Solo documenti non consegnati
      
      documento.righe.includes(:libro).each do |riga|
        titolo = riga.libro&.titolo || "Titolo N/D"
        quantita = riga.quantita || 0
        
        if @riassunto_titoli[titolo]
          @riassunto_titoli[titolo] += quantita
        else
          @riassunto_titoli[titolo] = quantita
        end
      end
    end

    respond_to do |format|
      format.pdf do
        pdf = DettaglioAppuntiDocumentiPdf.new(@appunti_dettagliati, @documenti_dettagliati, @giorno, view_context, @riassunto_titoli)
        send_data pdf.render, 
                  filename: "dettaglio_appunti_documenti_#{@giorno.strftime('%Y-%m-%d')}.pdf",
                  type: 'application/pdf',
                  disposition: 'inline'
      end
    end
  end

  private

    def load_giorno_entries
      @entries_per_tappa = {}

      @tappe.each do |tappa|
        tappable = tappa.tappable
        next unless tappable

        appunto_ids = []
        documento_ids = []

        if tappable.is_a?(Scuola)
          classe_ids = tappable.classi.pluck(:id)
          appunto_ids += Appunto.published.where(appuntabile: tappable).pluck(:id)
          appunto_ids += Appunto.published.where(appuntabile_type: "Classe", appuntabile_id: classe_ids).pluck(:id) if classe_ids.any?
          documento_ids += Documento.where(clientable: tappable).pluck(:id)
          documento_ids += Documento.where(clientable_type: "Classe", clientable_id: classe_ids).pluck(:id) if classe_ids.any?
        elsif tappable.is_a?(Cliente)
          appunto_ids += Appunto.published.where(appuntabile: tappable).pluck(:id)
          documento_ids += Documento.where(clientable: tappable).pluck(:id)
        end

        next if appunto_ids.empty? && documento_ids.empty?

        entries = Entry.where(account: Current.account)
                       .aperti
                       .where(
                         "(entryable_type = 'Appunto' AND entryable_id IN (?)) OR
                          (entryable_type = 'Documento' AND entryable_id IN (?))",
                         appunto_ids.map(&:to_s).presence || [""],
                         documento_ids.map(&:to_s).presence || [""]
                       )
                       .includes(:goldness, :closure, :not_now)
                       .order(updated_at: :desc)

        @entries_per_tappa[tappa] = entries if entries.any?
      end
    end

    def build_weeks(giorno, count, direction)
      monday = giorno.beginning_of_week

      case direction
      when "append"
        # Load `count` weeks starting from giorno's week
        (0...count).map { |i| helpers.dates_of_week(monday + (i * 7).days) }
      when "prepend"
        # Load `count` weeks ending at giorno's week
        (0...count).map { |i| helpers.dates_of_week(monday - ((count - 1 - i) * 7).days) }
      else
        # Initial load: 2 past + current + 2 future = 5 weeks
        offset = (count / 2)
        start_monday = monday - (offset * 7).days
        (0...count).map { |i| helpers.dates_of_week(start_monday + (i * 7).days) }
      end
    end
end
