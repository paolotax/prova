module MCPTools
  class Base < MCP::Tool
    def self.account(server_context)
      server_context[:account]
    end

    def self.user(server_context)
      server_context[:user]
    end

    def self.with_current(server_context)
      Current.user = server_context[:user]
      Current.account = server_context[:account]
      Current.membership = server_context[:membership] || server_context[:user]&.memberships&.find_by(account: server_context[:account])
      yield
    end
  end
end
