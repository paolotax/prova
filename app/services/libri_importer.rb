class LibriImporter

  include ActionView::Helpers::TextHelper
  include ActiveModel::Model

  attr_accessor :file, :imported_count, :updated_count, :errors_count, :import_method, :created_count

  def initialize(attributes = {})
    super
    @imported_count = 0
    @updated_count = 0
    @errors_count = 0
    @created_count = 0
  end

  def process!
    line_number = 1 # Header è la riga 1
    
    SmarterCSV.process(file.path) do |row|
      line_number += 1
      
      libro = assign_from_row(row.first)
      if libro.save
        if libro.previously_new_record?
          @imported_count += 1
        else
          @updated_count += 1
        end
      else
        @errors_count += 1
        errors.add(:base, "Riga #{line_number}: #{libro.errors.full_messages.join(", ")}")
        #return false
      end
    end
  end

  def import_ministeriali!
    sql = <<-SQL
      SELECT DISTINCT
        new_adozioni.codiceisbn AS codice_isbn,
        new_adozioni.titolo,
        editori.id AS editore_id,
        new_adozioni.annocorso as classe,
        new_adozioni.disciplina,
        COALESCE(TO_NUMBER(new_adozioni.prezzo, 'FM9G999G999D99S'), 0) AS prezzo_in_cents
      FROM new_adozioni
      INNER JOIN new_scuole ON new_adozioni.codicescuola = new_scuole.codice_scuola
      INNER JOIN user_scuole ON new_scuole.import_scuola_id = user_scuole.import_scuola_id
      INNER JOIN users ON user_scuole.user_id = users.id
      INNER JOIN editori ON editori.editore = new_adozioni.editore
      INNER JOIN mandati ON mandati.editore_id = editori.id AND mandati.user_id = users.id
      WHERE
        new_adozioni.daacquist = 'Si'
      AND
        users.id = #{Current.user.id}
    SQL

    result = ActiveRecord::Base.connection.execute(sql)
    categoria_ministeriali = Categoria.find_or_create_by(nome_categoria: "Ministeriali")

    record_number = 0
    result.each do |row|
      record_number += 1
      libro = assign_from_row_ministeriali(row, categoria_ministeriali)
      if libro.save
        if libro.previously_new_record?
          @imported_count += 1
        else
          @updated_count += 1
        end
      else
        @errors_count += 1
        errors.add(:base, "Record #{record_number} (ISBN: #{row['codice_isbn']}): #{libro.errors.full_messages.join(", ")}")
        #return false
      end
    end
  end

  def import_excel!
    xlsx = Roo::Spreadsheet.open(file.path, { csv_options: { encoding: 'bom|utf-8', col_sep: ";" } })
    
    # columns = xlsx.sheet(0).first_row
    # raise columns.inspect

    xlsx.default_sheet = xlsx.sheets.first 
    
    header = xlsx.row(1) 
    header.map! { |h| h.downcase.gsub(" ", "_").to_sym }

    2.upto(xlsx.last_row) do |line|  
      row_data = Hash[header.zip xlsx.row(line)]

      libro = assign_from_row(row_data)

      if libro.save
        if libro.previously_new_record?
          @imported_count += 1
        else
          @updated_count += 1
        end
      else
        @errors_count += 1
        errors.add(:base, "Riga #{line}: #{libro.errors.full_messages.join(", ")}")
        #return false
      end
    end
  
  end
  
  def import_confezioni_excel!
    xlsx = Roo::Spreadsheet.open(file.path)
    xlsx.default_sheet = xlsx.sheets.first

    header = xlsx.row(1)
    header.map! { |h| h.downcase.gsub(" ", "_").to_sym }

    user_id = Current.user.id

    2.upto(xlsx.last_row) do |line|
      row_data = Hash[header.zip xlsx.row(line)]

      confezione_isbn = row_data[:confezione_isbn]
      fascicolo_isbn = row_data[:fascicolo_isbn]
      row_order = row_data[:row_order].to_i

      # Trova i libri dell'utente corrente usando gli ISBN
      confezione = Libro.find_by(codice_isbn: confezione_isbn, user_id: user_id)
      fascicolo = Libro.find_by(codice_isbn: fascicolo_isbn, user_id: user_id)

      if confezione.nil?
        @errors_count += 1
        errors.add(:base, "Riga #{line}: Libro confezione con ISBN #{confezione_isbn} non trovato")
        next
      end

      if fascicolo.nil?
        @errors_count += 1
        errors.add(:base, "Riga #{line}: Libro fascicolo con ISBN #{fascicolo_isbn} non trovato")
        next
      end

      # Verifica se la relazione esiste già
      existing = ConfezioneRiga.find_by(
        confezione_id: confezione.id,
        fascicolo_id: fascicolo.id
      )

      if existing
        # Aggiorna il row_order se necessario
        if existing.row_order != row_order
          # Usa update_column per bypassare i callback di positioned
          existing.update_column(:row_order, row_order)
          @updated_count += 1
        end
      else
        # Crea nuova relazione con row_order specifico
        confezione_riga = ConfezioneRiga.new(
          confezione_id: confezione.id,
          fascicolo_id: fascicolo.id
        )

        # Salva prima senza row_order (positioned lo assegnerà automaticamente)
        if confezione_riga.save
          # Poi imposta il row_order corretto bypassando i callback
          confezione_riga.update_column(:row_order, row_order) if row_order.present?
          @created_count += 1
        else
          @errors_count += 1
          errors.add(:base, "Riga #{line}: #{confezione_riga.errors.full_messages.join(", ")}")
        end
      end
    end
  end

  def flash_message
    if @imported_count > 0 || @updated_count > 0 || @errors_count > 0 || @created_count > 0
      parts = []
      parts << pluralize(@imported_count, 'libro importato', 'libri importati') if @imported_count > 0
      parts << pluralize(@updated_count, 'libro aggiornato', 'libri aggiornati') if @updated_count > 0
      parts << pluralize(@created_count, 'confezione creata', 'confezioni create') if @created_count > 0
      parts << pluralize(@errors_count, 'errore', 'errori') if @errors_count > 0

      message = parts.join(" e ")
      message += " " + errors.full_messages[0..10].join(", ").html_safe if errors.any?
      message
    else
      "Nessun dato importato"
    end
  end

  def save
    import_excel!
    #errors.none?
  end

  private

    def assign_from_row_ministeriali(row, categoria)
      codice_isbn = row["codice_isbn"]
      user_id = Current.user.id

      libro = Libro.where(codice_isbn: codice_isbn, user_id: user_id).first_or_initialize do |l|
        l.categoria_id = categoria.id
      end

      # Forza categoria_id anche per record esistenti che non ce l'hanno
      libro.categoria_id ||= categoria.id

      libro.titolo = strip_tags(row["titolo"]) if row["titolo"].present?
      libro.editore_id = row["editore_id"] if row["editore_id"].present?
      libro.classe = row["classe"] if row["classe"].present?
      libro.disciplina = row["disciplina"] if row["disciplina"].present?
      libro.prezzo_in_cents = row["prezzo_in_cents"] if row["prezzo_in_cents"].present?

      libro
    end

    def assign_from_row(row)

      codice_isbn = row[:codice_isbn] || row["codice_isbn"] || row[:ean] || row["ean"]
      user_id = Current.user.id

      libro = Libro.where(codice_isbn: codice_isbn, user_id: user_id).first_or_initialize

      titolo = row[:titolo] || row["titolo"] || row[:descrizione] || row["descrizione"]
      libro.titolo = strip_tags(titolo) if titolo.present?

      if row[:prezzo].present?
        libro.prezzo = check_prezzo(row[:prezzo]) || 0.0
      end

      if row[:prezzo_suggerito].present?
        libro.prezzo_suggerito = check_prezzo(row[:prezzo_suggerito]) || 0.0
      end

      row.keys.each do |key|
        key_str = key.to_s
        next if key_str == "editore"
        next if key_str == "titolo"
        next if key_str == "prezzo"
        next if key_str == "prezzo_suggerito"
        next if key_str == "categoria"

        if libro.respond_to?("#{key}=")
          libro.send("#{key}=", row[key])
        end
      end

      # Gestione editore (dopo il loop per evitare conflitti)
      # Cerca solo l'editore esistente, non lo crea se non trovato
      if row[:editore].present? || row["editore"].present?
        nome_editore = row[:editore] || row["editore"]
        editore = Editore.find_by(editore: nome_editore)
        libro.editore = editore if editore
      end

      # Gestione categoria (dopo il loop per evitare conflitti)
      if row[:categoria].present? || row["categoria"].present?
        nome_categoria = row[:categoria] || row["categoria"]
        categoria = Categoria.find_or_create_by(nome_categoria: nome_categoria, user_id: user_id)
        libro.categoria = categoria
      elsif libro.new_record? && libro.categoria.nil?
        # Crea categoria di default per nuovi libri senza categoria
        categoria = Categoria.find_or_create_by(nome_categoria: "<nessuna>")
        libro.categoria = categoria
      end

      libro
    end

    def check_prezzo(prezzo)
      if prezzo.is_a? String
        prezzo = prezzo.gsub(",",".")
      end
      prezzo.to_s
    end

end