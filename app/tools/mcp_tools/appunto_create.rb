module MCPTools
  class AppuntoCreate < Base
    tool_name "appunto_create"
    description "Crea un nuovo appunto (nota/promemoria) associato a una scuola, cliente o persona. Usa il campo appuntabile_value ottenuto da search o persone."

    annotations(
      read_only_hint: false,
      destructive_hint: false,
      idempotent_hint: false
    )

    input_schema(
      type: "object",
      properties: {
        appuntabile_value: { type: "string", description: "Destinatario nel formato Tipo:UUID es. Scuola:uuid" },
        nome: { type: "string", description: "Titolo dell'appunto" },
        content: { type: "string", description: "Contenuto testuale" },
        publish: { type: "boolean", description: "Se true pubblica immediatamente" }
      },
      required: [ "appuntabile_value" ]
    )

    def self.call(appuntabile_value:, nome: nil, content: nil, publish: nil, server_context:, **_params)
      with_current(server_context) do
        creator = Appunti::AppuntoCreator.new({
          "appuntabile_value" => appuntabile_value,
          "nome" => nome,
          "content" => content,
          "publish" => publish
        }.compact)
        creator.create

        if creator.appunto&.persisted?
          result = {
            success: true,
            appunto_id: creator.appunto.id,
            nome: creator.appunto.nome,
            status: creator.appunto.status
          }
          MCP::Tool::Response.new([{ type: "text", text: result.to_json }])
        else
          result = {
            success: false,
            errors: creator.appunto&.errors&.full_messages || [ "Errore nella creazione dell'appunto" ]
          }
          MCP::Tool::Response.new([{ type: "text", text: result.to_json }], is_error: true)
        end
      rescue => e
        MCP::Tool::Response.new([{ type: "text", text: { error: e.message }.to_json }], is_error: true)
      end
    end
  end
end
