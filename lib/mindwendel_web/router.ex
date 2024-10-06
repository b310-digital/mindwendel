defmodule MindwendelWeb.Router do
  use MindwendelWeb, :router

  pipeline :browser do
    plug(:accepts, ["html", "csv"])
    plug(:fetch_session)
    plug(:fetch_live_flash)
    plug(:put_root_layout, {MindwendelWeb.Layouts, :root})
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
      live("/brainstormings/:id/empty", BrainstormingLive.Edit, :empty)
    end

    post("/brainstormings", BrainstormingController, :create)

    live "/brainstormings/:id", BrainstormingLive.Show, :show
    live "/brainstormings/:id/show/edit", BrainstormingLive.Show, :edit
    # Maybe rather "/brainstormings/:id/ideas/new" ?
    live "/brainstormings/:id/show/lanes/:lane_id/new_idea", BrainstormingLive.Show, :new_idea
    live "/brainstormings/:id/show/new_lane", BrainstormingLive.Show, :new_lane
    live "/brainstormings/:id/show/share", BrainstormingLive.Show, :share

    live "/brainstormings/:brainstorming_id/ideas/:idea_id/edit",
         BrainstormingLive.Show,
         :edit_idea

    live "/brainstormings/:brainstorming_id/lanes/:lane_id/edit",
         BrainstormingLive.Show,
         :edit_lane
  end

  # Other scopes may use custom stacks.
  # scope "/api", MindwendelWeb do
  #   pipe_through :api
  # end
end
