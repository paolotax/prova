class ClientiImporter
  
	include ActionView::Helpers::TextHelper
	include ActiveModel::Model
  
	attr_accessor  :file, :imported_count, :updated_count, :errors_count, :import_method

	def initialize(attributes = {})
		super
		@imported_count = 0
		@updated_count = 0
		@errors_count = 0
	end

	def process!

		options = { convert_values_to_numeric: { except: [:partita_iva, :codice_fiscale, :telefono] } }
    SmarterCSV.process(file.path, options) do |row|
      
      cliente = assign_from_row(row.first)
      if cliente.save
        if cliente.previously_new_record?
          @imported_count += 1
        else
          @updated_count += 1
        end
      else
				@errors_count += 1
				errors.add(:base, "Line #{$.} - #{cliente.errors.full_messages.join(", ")}")
				#return false
      end
		end
	end

	def save
		process!
		errors.none?
	end

	def flash_message
    if @imported_count > 0 || @updated_count > 0 || @errors_count > 0
      pluralize(@imported_count, 'cliente importato', 'clienti importati') + " e " + 
      pluralize(@updated_count, 'cliente aggiornato', 'clienti aggiornati') + " e " + 
      pluralize(@errors_count, 'cliente errato', 'clienti errati') + 
      " " + errors.full_messages.join(", ").html_safe
    else
      "Nessun cliente importato"
    end
  end

  private

		def assign_from_row(row)
			puts row[:partita_iva]
			if row[:denominazione].nil?
				cliente = Current.user.clienti.where(codice_fiscale: row[:codice_fiscale]).first_or_initialize      
			else
				cliente = Current.user.clienti.where(denominazione: row[:denominazione]).first_or_initialize
			end
			cliente.assign_attributes row.to_hash
			cliente
		end


end