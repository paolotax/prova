class Cliente::Import
  include ActiveModel::Model
  attr_accessor :file, :imported_count

	def process!
		@imported_count = 0

		# CSV.foreach(file.path, headers: true, col_sep: ';', header_converters: :symbol) do |row|
		
		options = { convert_values_to_numeric: { except: [:partita_iva, :codice_fiscale, :telefono] } }
		SmarterCSV.process(file.path, options) do |row|
			cliente = Cliente.assign_from_row(row.first)
			if cliente.save
				@imported_count += 1
			else
				errors.add(:base, "Line #{$.} - #{cliente.errors.full_messages.join(", ")}")
				return false
			end
		end
	end

	def save
		process!
		errors.none?
	end
end