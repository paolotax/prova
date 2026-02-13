# frozen_string_literal: true

module Imports
  class InsegnantiProcessor < BaseProcessor
    protected

    def process_file
      scuola_id = @metadata["scuola_id"]
      return add_error("Scuola non specificata nei metadata") unless scuola_id

      scuola = Scuola.find_by(id: scuola_id)
      return add_error("Scuola non trovata (id: #{scuola_id})") unless scuola

      path = file_path
      file = File.open(path)

      importer = AnarpeImporter.new(file: file, scuola: scuola)
      importer.call

      @imported_count = importer.imported_count
      @errors_count = importer.errors_list.size
      @errors = importer.errors_list.first(50)
    ensure
      file&.close
    end
  end
end
