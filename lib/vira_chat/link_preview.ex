defmodule ViraChat.LinkPreview do
  @moduledoc """
  Fetches Open Graph metadata from the first URL found in a message.
  Runs synchronously — call from a Task for non-blocking behavior.
  """

  @url_regex ~r/https?:\/\/[^\s<>"]+/i

  @doc """
  Extracts the first URL from `content`, or nil.
  """
  def first_url(content) when is_binary(content) do
    case Regex.run(@url_regex, content) do
      [url | _] -> url
      _ -> nil
    end
  end

  def first_url(_), do: nil

  @doc """
  Fetches the URL and returns a map with :title, :description, :image, :url
  or nil if the fetch fails.
  """
  def fetch(url) when is_binary(url) do
    case Req.get(url,
           receive_timeout: 5_000,
           max_redirects: 3,
           retry: false,
           headers: [{"user-agent", "ViraChat/1.0 LinkPreview"}]
         ) do
      {:ok, %{status: status, body: body}} when status in 200..299 ->
        parse_og(body, url)

      _ ->
        nil
    end
  rescue
    _ -> nil
  end

  defp parse_og(html, url) when is_binary(html) do
    try do
      doc = Floki.parse_document!(html)

      title =
        og_meta(doc, "og:title") || og_meta(doc, "twitter:title") ||
          page_title(doc)

      description =
        og_meta(doc, "og:description") || og_meta(doc, "twitter:description") ||
          page_description(doc)

      image = og_meta(doc, "og:image") || og_meta(doc, "twitter:image")

      if title || description || image do
        %{
          "title" => truncate(title, 120),
          "description" => truncate(description, 300),
          "image" => image,
          "url" => url
        }
      else
        nil
      end
    rescue
      _ -> nil
    end
  end

  defp parse_og(_html, _url), do: nil

  defp og_meta(doc, property) do
    doc
    |> Floki.find("meta[property='#{property}'], meta[name='#{property}']")
    |> Floki.attribute("content")
    |> List.first()
    |> presence()
  end

  defp page_title(doc) do
    doc
    |> Floki.find("title")
    |> Floki.text()
    |> presence()
  end

  defp page_description(doc) do
    doc
    |> Floki.find("meta[name='description']")
    |> Floki.attribute("content")
    |> List.first()
    |> presence()
  end

  defp presence(nil), do: nil
  defp presence(""), do: nil
  defp presence(s), do: String.trim(s)

  defp truncate(nil, _), do: nil
  defp truncate(s, max) when byte_size(s) <= max, do: s
  defp truncate(s, max), do: String.slice(s, 0, max) <> "…"
end
