module MCPTools
  class EntriesStato < Base
    tool_name "entries_stato"
    description "Gestisce gli stati trasversali di un'entry (appunto/documento/tappa): gold, close, postpone, move in una column kanban, triage. Azioni: gold, ungold, close, reopen, postpone, resume, move, triage."

    annotations(read_only_hint: false, destructive_hint: false, idempotent_hint: true)

    AZIONI = %w[gold ungold close reopen postpone resume move triage].freeze

    input_schema(
      type: "object",
      properties: {
        entry_id: { type: "string", description: "UUID dell'entry" },
        azione: { type: "string", description: "Azione: #{AZIONI.join(', ')}" },
        column: { type: "string", description: "Nome o UUID della column kanban (richiesto per azione 'move')" }
      },
      required: %w[entry_id azione]
    )

    def self.call(entry_id:, azione:, column: nil, server_context:, **_params)
      with_current(server_context) do
        entry = Current.account.entries.find(entry_id)

        case azione.downcase
        when "gold"
          entry.gild
        when "ungold"
          entry.ungild
        when "close"
          Entry.suppressing_turbo_broadcasts { entry.close }
        when "reopen"
          Entry.suppressing_turbo_broadcasts { entry.reopen }
        when "postpone"
          Entry.suppressing_turbo_broadcasts { entry.postpone }
        when "resume"
          Entry.suppressing_turbo_broadcasts { entry.resume }
        when "move"
          col = find_column(column)
          return error_response("Column non trovata: #{column}") unless col
          Entry.suppressing_turbo_broadcasts { entry.move_to_column(col) }
        when "triage"
          Entry.suppressing_turbo_broadcasts { entry.send_back_to_triage }
        else
          return error_response("Azione non valida: #{azione}. Usa: #{AZIONI.join(', ')}")
        end

        entry.reload
        MCP::Tool::Response.new([{
          type: "text",
          text: {
            ok: true,
            azione: azione,
            entry_id: entry.id,
            stato: {
              golden: entry.gilded_at.present?,
              closed: entry.closed?,
              postponed: entry.postponed?,
              column: entry.column&.name,
              column_id: entry.column&.id
            }
          }.to_json
        }])
      rescue ActiveRecord::RecordNotFound
        error_response("Entry non trovata")
      rescue => e
        error_response(e.message)
      end
    end

    def self.find_column(identifier)
      return nil if identifier.blank?

      if identifier.to_s.match?(/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i)
        Current.account.columns.find_by(id: identifier)
      else
        Current.account.columns.find_by(name: identifier)
      end
    end

    def self.error_response(message)
      MCP::Tool::Response.new([{ type: "text", text: { error: message }.to_json }], error: true)
    end
  end
end
