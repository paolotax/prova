# frozen_string_literal: true

module Imports
  class ClientiProcessor < BaseProcessor
    protected

    def process_file
      parse_excel do |row, line|
        cliente = assign_from_row(row)
        track_result(cliente, line: line)
      end
    end

    private

    def assign_from_row(row)
      cliente = if row[:partita_iva].nil?
        @user.clienti.where(codice_fiscale: row[:codice_fiscale]).first_or_initialize
      else
        @user.clienti.where(partita_iva: row[:partita_iva]).first_or_initialize
      end

      # Filter out keys that shouldn't be mass-assigned
      safe_attributes = row.to_hash.except(:id, :user_id, :created_at, :updated_at)
      cliente.assign_attributes(safe_attributes)
      cliente
    end
  end
end
