defmodule MindwendelWeb.Router do
  use MindwendelWeb, :router

  pipeline :browser do
    plug :accepts, ["html", "csv"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, {MindwendelWeb.LayoutView, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug Mindwendel.Plugs.SetSessionUserId
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", MindwendelWeb do
    pipe_through :browser

    get "/", StaticPageController, :home

    scope "/admin", Admin, as: :admin do
      resources "/brainstormings", BrainstormingController, except: [:index, :show, :new, :create]
      get "/brainstormings/:id/export", BrainstormingController, :export
    end

    post "/brainstormings", BrainstormingController, :create

    live "/brainstormings/:id", BrainstormingLive.Show, :show
    live "/brainstormings/:id/show/edit", BrainstormingLive.Show, :edit
    live "/brainstormings/:id/show/new_idea", BrainstormingLive.Show, :new_idea
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
