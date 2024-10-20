class LibriImporter

  include ActionView::Helpers::TextHelper
  include ActiveModel::Model
  
  attr_accessor :file, :imported_count, :updated_count, :errors_count, :import_method

  def initialize(attributes = {})
    super
    @imported_count = 0
    @updated_count = 0
    @errors_count = 0
  end

  def process!

    SmarterCSV.process(file.path) do |row|
      
      libro = assign_from_row(row.first)
      if libro.save
        if libro.previously_new_record?
          @imported_count += 1
        else
          @updated_count += 1
        end
      else
        @errors_count += 1
        errors.add(:base, "Line #{$.} - #{libro.errors.full_messages.join(", ")}")
        #return false
      end
    end
  end

  def import_ministeriali!
      
    sql = File.open(file).read
    sql.gsub!("{{user.id}}", "#{Current.user.id}")
    result = ActiveRecord::Base.connection.execute(sql)
    
    result.each do |row|
      libro = assign_from_row(row)
      if libro.save
        if libro.previously_new_record?
          @imported_count += 1
        else
          @updated_count += 1
        end
      else
        @errors_count += 1
        errors.add(:base, "Line #{$.} - #{libro.errors.full_messages.join(", ")}")
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
        errors.add(:base, "Line #{$.} - #{libro.errors.full_messages.join(", ")}")
        #return false
      end
    end
  
  end
  
  def flash_message
    if @imported_count > 0 || @updated_count > 0 || @errors_count > 0
      pluralize(@imported_count, 'libro importato', 'libri importati') + " e " + 
      pluralize(@updated_count, 'libro aggiornato', 'libri aggiornati') + " e " + 
      pluralize(@errors_count, 'libro errato', 'libri errati') + 
      " " + errors.full_messages[0..10].join(", ").html_safe
    else
      "Nessun libro importato"
    end
  end

  def save
    import_excel!
    #errors.none?
  end

  private

    def assign_from_row(row)
 
      codice_isbn = row[:codice_isbn] || row["codice_isbn"] || row[:ean] || row["ean"]
      titolo = row[:titolo] || row["titolo"] || row[:descrizione] || row["descrizione"]
      user_id = Current.user.id
      
      libro = Libro.where(codice_isbn: codice_isbn, user_id: user_id).first_or_initialize
      libro.titolo = titolo
      libro.prezzo = check_prezzo(row[:prezzo]) || 0.0
      
      row.keys.each do |key|
        next if key == :editore
        next if key == :titolo                
        next if key == :prezzo

        if libro.respond_to?("#{key}=") 
          libro.send("#{key}=", row[key])
        end
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