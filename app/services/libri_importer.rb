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
        errors.add(:base, "Line #{$.} - #{libro.errors.full_messages.join(", ")} PIPPO")
        #return false
      end
    end
  end


  def flash_message
    if @imported_count > 0 || @updated_count > 0 || @errors_count > 0
      pluralize(@imported_count, 'libro importato', 'libri importati') + " e " + 
      pluralize(@updated_count, 'libro aggiornato', 'libri aggiornati') + " e " + 
      pluralize(@errors_count, 'libro errato', 'libri errati') + 
      " " + errors.full_messages.join(", ").html_safe
    else
      "Nessun libro importato"
    end
  end

  def save
    process!
    #errors.none?
  end

  private

    def assign_from_row(row)
 
      codice_isbn = row[:codice_isbn] || row["codice_isbn"]
      user_id = Current.user.id
      libro = Libro.where(codice_isbn: codice_isbn, user_id: user_id).first_or_initialize
      unless libro.new_record?
        if row[:titolo] then row.delete(:titolo) end
        if row["titolo"] then row.delete("titolo") end
      end
      libro.assign_attributes row.to_hash
      libro
    end
end