# frozen_string_literal: true

module Imports
  class BaseProcessor
    include ActionView::Helpers::TextHelper

    attr_reader :imported_count, :updated_count, :errors_count, :created_count, :errors

    def initialize(file, user)
      @file = file
      @user = user
      @imported_count = 0
      @updated_count = 0
      @errors_count = 0
      @created_count = 0
      @errors = []
    end

    def call
      process_file
      self
    end

    def success?
      errors_count.zero?
    end

    def flash_message
      return "Nessun dato importato" if total_count.zero?

      parts = []
      parts << pluralize(@imported_count, 'record importato', 'record importati') if @imported_count > 0
      parts << pluralize(@updated_count, 'record aggiornato', 'record aggiornati') if @updated_count > 0
      parts << pluralize(@created_count, 'record creato', 'record creati') if @created_count > 0
      parts << pluralize(@errors_count, 'errore', 'errori') if @errors_count > 0

      message = parts.join(" e ")
      message += ": " + @errors.first(10).join(", ") if @errors.any?
      message
    end

    def total_count
      @imported_count + @updated_count + @errors_count + @created_count
    end

    protected

    def process_file
      raise NotImplementedError, "Subclass must implement #process_file"
    end

    def track_result(record, line: nil)
      if record.save
        if record.previously_new_record?
          @imported_count += 1
        else
          @updated_count += 1
        end
        true
      else
        @errors_count += 1
        prefix = line ? "Riga #{line}: " : ""
        @errors << "#{prefix}#{record.errors.full_messages.join(', ')}"
        false
      end
    end

    def track_created(record, line: nil)
      if record.save
        @created_count += 1
        true
      else
        @errors_count += 1
        prefix = line ? "Riga #{line}: " : ""
        @errors << "#{prefix}#{record.errors.full_messages.join(', ')}"
        false
      end
    end

    def add_error(message, line: nil)
      @errors_count += 1
      prefix = line ? "Riga #{line}: " : ""
      @errors << "#{prefix}#{message}"
    end

    # Parse Excel file with normalized headers
    def parse_excel(start_row: 2)
      xlsx = Roo::Spreadsheet.open(file_path, csv_options: { encoding: 'bom|utf-8', col_sep: "," })
      xlsx.default_sheet = xlsx.sheets.first

      header = xlsx.row(1)
      header.map! { |h| h.to_s.downcase.gsub(" ", "_").to_sym }

      start_row.upto(xlsx.last_row) do |line|
        row = Hash[header.zip(xlsx.row(line))]
        yield row, line
      end
    end

    # Parse CSV file
    def parse_csv
      line_number = 1
      SmarterCSV.process(file_path) do |row|
        line_number += 1
        yield row.first, line_number
      end
    end

    def file_path
      if @file.respond_to?(:path)
        @file.path
      elsif @file.respond_to?(:download)
        # ActiveStorage attachment
        tempfile = Tempfile.new(['import', File.extname(@file.filename.to_s)])
        tempfile.binmode
        tempfile.write(@file.download)
        tempfile.rewind
        @tempfile = tempfile # Keep reference to avoid GC
        tempfile.path
      else
        @file.to_s
      end
    end

    def check_prezzo(prezzo)
      return "0.0" if prezzo.to_s.downcase.strip == "omaggio"

      if prezzo.is_a?(String)
        prezzo = prezzo.gsub(",", ".")
      end
      prezzo.to_s
    end
  end
end
