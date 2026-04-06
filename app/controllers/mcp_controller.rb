class MCPController < ActionController::API
  include Api::TokenAuthenticatable

  before_action :authenticate_api!

  def handle
    if request.raw_post.blank?
      head :accepted
      return
    end

    render json: mcp_server.handle_json(request.raw_post)
  end

  private

  def mcp_server
    ::MCP::Server.new(
      name: "scagnozz",
      version: "1.0.0",
      instructions: "Tools per gestire adozioni scolastiche, scuole, clienti, persone e libri",
      tools: mcp_tools,
      server_context: { user: Current.user, account: Current.account }
    )
  end

  def mcp_tools
    load_mcp_tools! if MCPTools::Base.subclasses.empty?
    MCPTools::Base.subclasses
  end

  def load_mcp_tools!
    Dir[Rails.root.join("app/tools/mcp_tools/*.rb")].each do |file|
      require_dependency file
    end
  end
end
