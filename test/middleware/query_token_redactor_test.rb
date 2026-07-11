require "test_helper"

class QueryTokenRedactorTest < ActiveSupport::TestCase
  test "promotes MCP api_key to bearer and removes it from the query string" do
    observed_env = nil
    app = lambda do |env|
      observed_env = env
      [200, {}, ["OK"]]
    end

    middleware = QueryTokenRedactor.new(app)
    env = Rack::MockRequest.env_for("/api/mcp?api_key=secret-token&source=chatgpt")

    middleware.call(env)

    assert_equal "Bearer secret-token", observed_env["HTTP_AUTHORIZATION"]
    assert_equal "source=chatgpt", observed_env["QUERY_STRING"]
  end

  test "does not overwrite an existing authorization header" do
    app = ->(env) { [200, { "authorization" => env["HTTP_AUTHORIZATION"] }, ["OK"]] }
    middleware = QueryTokenRedactor.new(app)
    env = Rack::MockRequest.env_for(
      "/api/mcp?api_key=query-token",
      "HTTP_AUTHORIZATION" => "Bearer header-token"
    )

    _status, headers, = middleware.call(env)

    assert_equal "Bearer header-token", headers["authorization"]
    assert_empty env["QUERY_STRING"]
  end

  test "does not alter query tokens on other endpoints" do
    app = ->(env) { [200, {}, [env["QUERY_STRING"]]] }
    middleware = QueryTokenRedactor.new(app)
    env = Rack::MockRequest.env_for("/other?api_key=visible")

    _status, _headers, body = middleware.call(env)

    assert_equal ["api_key=visible"], body
    assert_nil env["HTTP_AUTHORIZATION"]
  end
end
