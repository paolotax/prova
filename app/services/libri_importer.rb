class LibriImporter
  

  include ActiveModel::Model
  attr_accessor :file, :imported_count, :import_method

  def process!
    @imported_count = 0
    # CSV.foreach(file.path, headers: true, col_sep: ';', header_converters: :symbol) do |row|          
    SmarterCSV.process(file.path) do |row|
      libro = assign_from_row(row.first)
      #raise libro.inspect
      if libro.save
          @imported_count += 1
      else
          errors.add(:base, "Line #{$.} - #{libro.errors.full_messages.join(", ")}")
          return false
      end
    end
  end

  def import_ministeriali!
    @imported_count = 0

    sql = File.open(file).read
    sql.gsub!("{{user.id}}", "#{Current.user.id}")
    result = ActiveRecord::Base.connection.execute(sql)
    
    result.each do |row|
      libro = Libro.assign_from_row(row)
      if libro.save
        @imported_count += 1
      else
        puts "PIPPA: #{libro.inspect}"
        #errors.add(:base, "Line #{$.} - #{libro.errors.full_messages.join(", ")}")
        return false
      end
    end
  end

  def save
    process!
    errors.none?
  end

  private

    def assign_from_row(row)
      puts row["codice_isbn"]
      libro = Libro.where(codice_isbn: row[:codice_isbn], user_id: Current.user.id).first_or_initialize
      libro.assign_attributes row.to_hash
      libro
    end
end