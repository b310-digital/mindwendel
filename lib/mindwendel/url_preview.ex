defmodule Mindwendel.UrlPreview do
  def extract_url(string \\ "") do
    match =
      Regex.run(
        ~r/((?:http|https):\/\/[\w-]+\.[\w-]+[\w\.,@?^=%&:\/\~+#-]*[\w@?^=%&\/\~+#-]?)/,
        string
      )

    if match == nil do
      ""
    else
      List.first(match)
    end
  end

  def fetch_url(url \\ "") do
    with {:ok, uri} <- URI.new(url),
         true <- uri.scheme in ["http", "https"],
         true <- valid_host?(uri.host) do
      HTTPoison.start()

      url
      |> HTTPoison.get(
        [],
        timeout: 5_000,
        recv_timeout: 5_000,
        max_redirect: 3,
        follow_redirect: true
      )
      |> handle_response()
      |> handle_parsing()
    else
      _ -> {:error, title: "", description: "", img_preview_url: ""}
    end
  end

  defp valid_host?(host) when is_nil(host), do: false

  defp valid_host?(host) do
    # Allow localhost in test environment only
    if Mix.env() == :test do
      true
    else
      # Block private IP ranges and localhost to prevent SSRF attacks.
      # These ranges are defined by RFC 1918 (private networks) and RFC 3927 (link-local).
      # The 169.254.x.x range is particularly dangerous as it includes cloud metadata endpoints
      # (AWS, GCP, Azure) that expose credentials and sensitive configuration.
      case :inet.getaddr(String.to_charlist(host), :inet) do
        # localhost
        {:ok, {127, _, _, _}} ->
          false

        # private 10.x.x.x (RFC 1918)
        {:ok, {10, _, _, _}} ->
          false

        # private 172.16.0.0 - 172.31.255.255 (RFC 1918)
        {:ok, {172, second, _, _}} when second >= 16 and second <= 31 ->
          false

        # private 192.168.x.x (RFC 1918)
        {:ok, {192, 168, _, _}} ->
          false

        # link-local / cloud metadata 169.254.x.x (RFC 3927)
        {:ok, {169, 254, _, _}} ->
          false

        # invalid
        {:ok, {0, 0, 0, 0}} ->
          false

        # public IP
        {:ok, _} ->
          true

        # DNS resolution failed
        {:error, _} ->
          false
      end
    end
  end

  defp handle_parsing({:ok, parsed_document}) do
    {
      :ok,
      title: extract_title(parsed_document),
      description: extract_description(parsed_document),
      img_preview_url: extract_img_preview(parsed_document)
    }
  end

  defp handle_parsing({_, _}) do
    {:error, title: "", description: "", img_preview_url: ""}
  end

  defp handle_response({:ok, %HTTPoison.Response{status_code: 200, body: body}}) do
    body |> Floki.parse_document()
  end

  defp handle_response({:ok, %HTTPoison.Response{status_code: 404}}) do
    {:not_found, ""}
  end

  defp handle_response({:ok, _}) do
    {:unknown, ""}
  end

  defp handle_response({:error, _}) do
    {:error, ""}
  end

  defp extract_description(parsed_document) do
    parsed_document
    |> Floki.find("meta[name=description]")
    |> Floki.attribute("content")
    |> List.first("")
    |> String.slice(0, 300)
  end

  defp extract_title(parsed_document) do
    parsed_document
    |> Floki.find("title")
    |> Floki.text()
    |> String.slice(0, 300)
  end

  defp extract_img_preview(parsed_document) do
    parsed_document
    |> Floki.find("meta[property='og:image']")
    |> Floki.attribute("content")
    |> List.first() || ""
  end
end
