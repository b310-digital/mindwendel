defmodule Mindwendel.UrlPreview do
  @moduledoc false

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
    HTTPoison.start()
    url |> HTTPoison.get() |> handle_response |> handle_parsing
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
