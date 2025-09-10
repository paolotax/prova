class AgendaController < ApplicationController

  before_action :authenticate_user!
  
  def index  
    @giorno = params[:giorno]&.to_date || Date.today
    @settimana = helpers.dates_of_week(@giorno)
    # @settimana_precedente = helpers.dates_of_week(@giorno - 7.days)
    @tappe_per_giorno = current_user.tappe.della_settimana(@giorno).group_by(&:data_tappa)
    
    respond_to do |format|
      format.html # Render the full page initially
      format.turbo_stream do
        if params[:direction] == 'prepend'
          render turbo_stream: turbo_stream.prepend("week-container", partial: "agenda/week", locals: { settimana: @settimana, tappe_per_giorno: @tappe_per_giorno })
        else
          render turbo_stream: turbo_stream.append("week-container", partial: "agenda/week", locals: { settimana: @settimana, tappe_per_giorno: @tappe_per_giorno })
        end
      end
    end
  end

  def show
    @giorno = params[:giorno] ? Date.parse(params[:giorno]) : Date.today
    @scuole = current_user.import_scuole
                .includes(:appunti_da_completare)
                .where(id: current_user.tappe.del_giorno(@giorno).where(tappable_type: "ImportScuola").pluck(:tappable_id))        
    @clienti = current_user.clienti
                .where(id: current_user.tappe.del_giorno(@giorno).where(tappable_type: "Cliente").pluck(:tappable_id))
    
    @tappe = current_user.tappe.del_giorno(@giorno).includes(:tappable, :giri).order(:position)
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
        indirizzo.tappable_type == "ImportScuola" ? indirizzo.tappable_id : nil
      ]
    end
  end

  def slideover
    @giorno = params[:giorno] ? Date.parse(params[:giorno]) : Date.today
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
              is_scuola."DENOMINAZIONESCUOLA",
              is_scuola.id as scuola_id,
              ia."ANNOCORSO",
              STRING_AGG(DISTINCT ia."SEZIONEANNO", '' ORDER BY ia."SEZIONEANNO") as sezioni_concatenate,
              COUNT(ia.id) as adozioni_per_classe
          FROM import_adozioni ia
              INNER JOIN import_scuole is_scuola ON ia."CODICESCUOLA" = is_scuola."CODICESCUOLA"
              INNER JOIN editori e ON ia."EDITORE" = e.editore
              INNER JOIN mandati m ON e.id = m.editore_id
              INNER JOIN tappe t ON (
                  t.tappable_type = 'ImportScuola'
                  AND t.tappable_id = is_scuola.id
                  AND t.data_tappa = $1
                  AND t.user_id = $2
              )
          WHERE m.user_id = $2 AND ia."DAACQUIST" = 'Si'
          GROUP BY
              ia."TITOLO", ia."CODICEISBN", ia."EDITORE", ia."DISCIPLINA",
              is_scuola."DENOMINAZIONESCUOLA", is_scuola.id, ia."ANNOCORSO"
      ), saggi_per_adozione AS (
          SELECT
              ia."TITOLO",
              ia."CODICEISBN",
              ia."EDITORE",
              ia."DISCIPLINA",
              is_scuola."DENOMINAZIONESCUOLA",
              ia."ANNOCORSO",
              ia."SEZIONEANNO",
              COUNT(a.id) as numero_saggi
          FROM appunti a
              INNER JOIN import_adozioni ia ON a.import_adozione_id = ia.id
              INNER JOIN import_scuole is_scuola ON ia."CODICESCUOLA" = is_scuola."CODICESCUOLA"
              INNER JOIN tappe t ON (
                  t.tappable_type = 'ImportScuola'
                  AND t.tappable_id = is_scuola.id
                  AND t.data_tappa = $1
                  AND t.user_id = $2
              )
          WHERE a.nome = 'saggio' AND a.user_id = $2
          GROUP BY ia."TITOLO", ia."CODICEISBN", ia."EDITORE", ia."DISCIPLINA",
                   is_scuola."DENOMINAZIONESCUOLA", ia."ANNOCORSO", ia."SEZIONEANNO"
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
        ActiveRecord::Relation::QueryAttribute.new('user_id', current_user.id, ActiveRecord::Type::Integer.new)
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

end
