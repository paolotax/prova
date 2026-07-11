class QueryTokenRedactor
  MCP_PATH = "/api/mcp"
  TOKEN_PARAMETER = "api_key"

  def initialize(app)
    @app = app
  end

  def call(env)
    promote_query_token(env) if env["PATH_INFO"] == MCP_PATH
    @app.call(env)
  end

  private

  def promote_query_token(env)
    params = Rack::Utils.parse_nested_query(env["QUERY_STRING"].to_s)
    token = params.delete(TOKEN_PARAMETER)
    return if token.blank?

    env["HTTP_AUTHORIZATION"] ||= "Bearer #{token}"
    env["QUERY_STRING"] = Rack::Utils.build_nested_query(params)
  end
end
