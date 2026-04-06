module MCPTools
  class Me < Base
    tool_name "me"
    description "Restituisce le informazioni dell'utente autenticato: nome, email, account corrente e ruolo."

    annotations(
      read_only_hint: true,
      destructive_hint: false,
      idempotent_hint: true
    )

    input_schema(
      type: "object",
      properties: {}
    )

    def self.call(server_context:, **_params)
      user = server_context[:user]
      account = server_context[:account]

      MCP::Tool::Response.new([{
        type: "text",
        text: {
          email: user.email,
          name: user.name,
          account: account.name,
          account_id: account.id
        }.to_json
      }])
    end
  end
end
