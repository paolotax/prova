# frozen_string_literal: true

module Imports
  class ClientiProcessor < BaseProcessor
    protected

    def process_file
      if excel_file?
        parse_excel do |row, line|
          cliente = assign_from_row(row)
          track_result(cliente, line: line)
        end
      else
        parse_csv_clienti do |row, line|
          cliente = assign_from_row(row)
          track_result(cliente, line: line)
        end
      end
    end

    private

    def excel_file?
      ext = if @file.respond_to?(:filename)
        File.extname(@file.filename.to_s)
      elsif @file.respond_to?(:original_filename)
        File.extname(@file.original_filename)
      else
        File.extname(@file.to_s)
      end
      %w[.xlsx .xls].include?(ext.downcase)
    end

    def parse_csv_clienti
      line_number = 1
      options = { convert_values_to_numeric: { except: [:partita_iva, :codice_fiscale, :telefono] } }
      SmarterCSV.process(file_path, options) do |row|
        line_number += 1
        yield row.first, line_number
      end
    end

    def assign_from_row(row)
      cliente = if row[:partita_iva].nil?
        @account.clienti.where(codice_fiscale: row[:codice_fiscale]).first_or_initialize
      else
        @account.clienti.where(partita_iva: row[:partita_iva]).first_or_initialize
      end

      cliente.account_id ||= @account&.id if @account

      # Filter out keys that shouldn't be mass-assigned
      safe_attributes = row.to_hash.except(:id, :user_id, :account_id, :created_at, :updated_at)
      cliente.assign_attributes(safe_attributes)
      cliente
    end
  end
end
