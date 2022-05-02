defmodule MindwendelWeb.Router do
  use MindwendelWeb, :router

  @host :mindwendel
        |> Application.fetch_env!(MindwendelWeb.Endpoint)
        # |> Keyword.fetch!(:http)
        # |> Keyword.fetch!(:ip)
        # |> Tuple.to_list()
        # |> Enum.join(".")
        |> Keyword.fetch!(:url)
        |> Keyword.fetch!(:host)

  @port :mindwendel
        |> Application.fetch_env!(MindwendelWeb.Endpoint)
        |> Keyword.fetch!(:http)
        |> Keyword.fetch!(:port)

  @content_security_policy (case Mix.env() do
                              :prod ->
                                "default-src 'self';" <>
                                  "connect-src wss://#{@host};"

                              _ ->
                                "default-src 'self' 'unsafe-eval';" <>
                                  "connect-src ws://0.0.0.0:4000 ws://localhost:4000 http://0.0.0.0:4000 http://localhost:4000;" <>
                                  "img-src 'self' blob: data:;" <>
                                  "style-src 'self' 'unsafe-inline'"
                            end)

  pipeline :browser do
    plug :accepts, ["html", "csv"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, {MindwendelWeb.LayoutView, :root}
    plug :protect_from_forgery

    plug :put_secure_browser_headers,
         %{"content-security-policy" => @content_security_policy}

    plug Mindwendel.Plugs.SetSessionUserId
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", MindwendelWeb do
    pipe_through :browser

    get "/", StaticPageController, :home

    scope "/admin", Admin, as: :admin do
      delete "/brainstormings/:id", BrainstormingController, :delete
      get "/brainstormings/:id/export", BrainstormingController, :export
      live "/brainstormings/:id/edit", BrainstormingLive.Edit, :edit
    end

    post "/brainstormings", BrainstormingController, :create

    live "/brainstormings/:id", BrainstormingLive.Show, :show
    live "/brainstormings/:id/show/edit", BrainstormingLive.Show, :edit
    live "/brainstormings/:id/show/new_idea", BrainstormingLive.Show, :new_idea
    live "/brainstormings/:id/show/share", BrainstormingLive.Show, :share
  end

  # Other scopes may use custom stacks.
  # scope "/api", MindwendelWeb do
  #   pipe_through :api
  # end

  # Enables LiveDashboard only for development
  #
  # If you want to use the LiveDashboard in production, you should put
  # it behind authentication and allow only admins to access it.
  # If your application does not have an admins-only section yet,
  # you can use Plug.BasicAuth to set up some basic authentication
  # as long as you are also using SSL (which you should anyway).
  if Mix.env() in [:dev, :test] do
    import Phoenix.LiveDashboard.Router

    scope "/" do
      pipe_through :browser
      live_dashboard "/dashboard", metrics: MindwendelWeb.Telemetry
    end
  end
end
