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
    if allow_private_ips?() do
      true
    else
      check_public_ip(host)
    end
  end

  defp allow_private_ips? do
    Application.get_env(:mindwendel, :allow_private_ips, false)
  end

  defp check_public_ip(host) do
    # Block private IP ranges and localhost to prevent SSRF attacks.
    # These ranges are defined by RFC 1918 (private networks) and RFC 3927 (link-local).
    # The 169.254.x.x range is particularly dangerous as it includes cloud metadata endpoints
    # (AWS, GCP, Azure) that expose credentials and sensitive configuration.
    case :inet.getaddr(String.to_charlist(host), :inet) do
      {:ok, ip_tuple} -> public_ip?(ip_tuple)
      {:error, _} -> false
    end
  end

  defp public_ip?(ip_tuple) do
    not private_ip?(ip_tuple)
  end

  defp private_ip?({127, _, _, _}), do: true
  defp private_ip?({10, _, _, _}), do: true
  defp private_ip?({172, second, _, _}) when second >= 16 and second <= 31, do: true
  defp private_ip?({192, 168, _, _}), do: true
  defp private_ip?({169, 254, _, _}), do: true
  defp private_ip?({0, 0, 0, 0}), do: true
  defp private_ip?(_), do: false

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
