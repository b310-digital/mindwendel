defmodule Mindwendel.Plugs.SetResponseHeaderContentSecurityPolicy do
  @content_secrity_policy_response_header_key "content-security-policy"

  # @impl true
  def init(opts) do
    opts
  end

  # @impl true
  def call(%Plug.Conn{} = conn, _opts) do
    Plug.Conn.put_resp_header(
      conn,
      @content_secrity_policy_response_header_key,
      content_security_policy_directives()
    )
  end

  def content_security_policy_directives() do
    # Usually, the csp directive `connect-src 'self'` is enough,
    # see https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Content-Security-Policy/connect-src .
    #
    # However, the `connect-src 'self'` does not resolve to websocket schemes in all browsers, e.g. Safari,
    # see https://github.com/w3c/webappsec-csp/issues/7 .
    #
    # Therefore, we need to explicitly add the allowed websocket uris here so that live views will work in safari in combination with CSP policies.
    # e.g. `connect-src ws://localhost:*` or `connect-src wss://#{@host}` .
    "default-src 'none' ; " <>
      "connect-src 'self' #{%URI{scheme: get_websocket_scheme(), host: get_host(), port: get_port()}} ; " <>
      "font-src    'self' ; " <>
      "frame-src   'self' ; " <>
      "img-src     'self' data: ; " <>
      "script-src  'self' 'unsafe-eval' ; " <>
      "style-src   'self' 'unsafe-inline' ; "
  end

  def get_host() do
    :mindwendel
    |> Application.fetch_env!(MindwendelWeb.Endpoint)
    |> Keyword.fetch!(:url)
    |> Keyword.fetch!(:host)
  end

  def get_scheme() do
    :mindwendel
    |> Application.fetch_env!(MindwendelWeb.Endpoint)
    |> Keyword.fetch!(:url)
    |> Keyword.fetch!(:scheme)
  end

  def get_port() do
    :mindwendel
    |> Application.fetch_env!(MindwendelWeb.Endpoint)
    |> Keyword.fetch!(:url)
    |> Keyword.fetch!(:port)
  end

  def get_websocket_scheme() do
    get_scheme() |> get_websocket_scheme()
  end

  def get_websocket_scheme("http") do
    "ws"
  end

  def get_websocket_scheme("https") do
    "wss"
  end
end
