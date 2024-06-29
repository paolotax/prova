class NewAdozione::Import
  include ActiveModel::Model
  attr_accessor :file, :imported_count

	def process!
		@imported_count = 0
		# CSV.foreach(file.path, headers: true, col_sep: ';', header_converters: :symbol) do |row|
		# 	adozione = NewAdozione.assign_from_row(row)
		# 	if adozione.save
		# 		@imported_count += 1
		# 	else
		# 		errors.add(:base, "Line #{$.} - #{adozione.errors.full_messages.join(", ")}")
		# 		return false
		# 	end
		# end
		# true
        SmarterCSV.process(file.path, { chunk_size: 10000 }) do |chunk|
           
            #NewAdozione.import chunk, on_duplicate_key_update: { conflict_target: [:codicescuola, :annocorso, :sezioneanno, :combinazione, :codiceisbn], columns: [:anno_scolastico, :annocorso, :autori, :codiceisbn, :codicescuola, :combinazione, :consigliato, :daacquist, :disciplina, :editore, :nuovaadoz, :prezzo, :sezioneanno, :sottotitolo, :tipogradoscuola, :titolo, :volume, :import_scuola_id] }
            NewAdozione.import chunk

        end

	end

	def save
		process!
		errors.none?
	end
end