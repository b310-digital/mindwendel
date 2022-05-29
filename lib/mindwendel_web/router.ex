defmodule MindwendelWeb.Router do
  use MindwendelWeb, :router

  pipeline :browser do
    plug(:accepts, ["html", "csv"])
    plug(:fetch_session)
    plug(:fetch_live_flash)
    plug(:put_root_layout, {MindwendelWeb.LayoutView, :root})
    plug(:protect_from_forgery)

    # Ususally, you can directly include the csp header in this borwser pipeline like this
    # plug(
    #   :put_secure_browser_headers,
    #   %{"content-security-policy" => @content_security_policy}
    # )
    #
    # See https://furlough.merecomplexities.com/elixir/phoenix/security/2021/02/26/content-security-policy-configuration-in-phoenix.html
    # See https://elixirforum.com/t/phoenix-blog-post-content-security-policy-configuration-in-phoenix-with-liveview/37809
    #
    # However for this to work, we would need to know / define the env var URL_HOST and URL_PORT during compile-time as the router and its pipelines are compiled.
    # This is certainly a problem when deploying the app with `mix release` as we do not know the URl_HOST etc. at this moment.
    #
    # Therefore, we are setting the CSP header dynamically in a custom plug after we set the other secure browser headers.
    #
    # The static analysis tool sobelow wants us to include the CSP header when calling this plug. It does not recognize that
    # the CSP header is included in a custom plug. This is why we need to skip this check here.
    # sobelow_skip(["Config.CSP"])
    plug(:put_secure_browser_headers)
    plug(Mindwendel.Plugs.SetResponseHeaderContentSecurityPolicy)

    plug(Mindwendel.Plugs.SetSessionUserId)
  end

  pipeline :api do
    plug(:accepts, ["json"])
  end

  scope "/", MindwendelWeb do
    pipe_through(:browser)

    get("/", StaticPageController, :home)

    scope "/admin", Admin, as: :admin do
      delete("/brainstormings/:id", BrainstormingController, :delete)
      get("/brainstormings/:id/export", BrainstormingController, :export)
      live("/brainstormings/:id/edit", BrainstormingLive.Edit, :edit)
    end

    post("/brainstormings", BrainstormingController, :create)

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
      pipe_through(:browser)
      live_dashboard("/dashboard", metrics: MindwendelWeb.Telemetry)
    end
  end
end
