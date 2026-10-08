defmodule MindwendelWeb.LinkPreviewController do
  use MindwendelWeb, :controller

  alias Mindwendel.Attachments
  alias Mindwendel.RateLimiter
  alias Mindwendel.UrlPreview
  alias MindwendelWeb.ErrorHTML

  # Each request fetches the image again, so the number of fetches per image host
  # is limited to prevent abusing the proxy to download large images repeatedly.
  # The limit is per host, so posting many (different) urls of a host does not
  # raise it. In the worst case, a preview image is not shown.
  @default_rate_limit 60
  @default_rate_limit_window_ms :timer.minutes(1)

  # Proxies the link preview image, so that browsers only load images from the
  # app origin and third-party servers never see the participants' IP addresses
  def get_image(conn, %{"id" => id}) do
    with {:ok, _} <- Ecto.UUID.cast(id),
         %{img_preview_url: url} when is_binary(url) and url != "" <-
           Attachments.get_link(id),
         url = absolute_url(url),
         :ok <- check_rate_limit(url),
         {:ok, content_type, image} <- UrlPreview.fetch_image(url) do
      conn
      |> put_resp_header("x-content-type-options", "nosniff")
      |> put_resp_header("cache-control", "private, max-age=86400")
      |> put_resp_content_type(content_type, nil)
      |> send_resp(200, image)
    else
      {:error, :rate_limited} ->
        conn
        |> put_resp_header("retry-after", to_string(div(rate_limit_window_ms(), 1000)))
        |> send_resp(:too_many_requests, "")

      _ ->
        # Browsers should not request a broken image on every page load
        conn
        |> put_resp_header("cache-control", "private, max-age=3600")
        |> render_404()
    end
  end

  defp check_rate_limit(url),
    do: RateLimiter.hit({:link_preview_image, host(url)}, rate_limit(), rate_limit_window_ms())

  # "Example.com." and "example.com" are the same host
  defp host(url) do
    case URI.parse(url) do
      %URI{host: host} when is_binary(host) ->
        host |> String.downcase() |> String.trim_trailing(".")

      _ ->
        nil
    end
  end

  defp rate_limit, do: config(:rate_limit, @default_rate_limit)
  defp rate_limit_window_ms, do: config(:rate_limit_window_ms, @default_rate_limit_window_ms)

  defp config(key, default),
    do: :mindwendel |> Application.get_env(__MODULE__, []) |> Keyword.get(key, default)

  # Browsers loaded protocol-relative urls (stored before urls were resolved
  # against the page url) via the scheme of the app
  defp absolute_url("//" <> _ = url), do: "https:" <> url
  defp absolute_url(url), do: url

  defp render_404(conn) do
    conn
    |> put_status(:not_found)
    |> put_view(ErrorHTML)
    |> put_layout(false)
    |> put_root_layout(false)
    |> render(:"404")
    |> halt()
  end
end
