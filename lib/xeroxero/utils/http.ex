defmodule XeroXero.Utils.Http do
  @connection_timeout 330_000
  @default_headers [{"Accept", "application/json"}]

  def get(url, headers) do
    # ++ [{:proxy, "127.0.0.1:8888"}]
    headers = headers ++ @default_headers
    {:ok, response} = HTTPoison.get(url, headers, [{:recv_timeout, @connection_timeout}])

    response
  end

  def put(url, headers, data_map) do
    {_, payload} = Jason.encode(data_map)

    headers = headers ++ @default_headers
    # ++ [{:proxy, "127.0.0.1:8888"}]
    {:ok, response} = HTTPoison.put(url, payload, headers, [{:recv_timeout, @connection_timeout}])

    response
  end

  def post(url, headers, data_map) do
    {_, payload} = Jason.encode(data_map)
    headers = headers ++ @default_headers

    # ++ [{:proxy, "127.0.0.1:8888"}]
    {:ok, response} =
      HTTPoison.post(url, payload, headers, [{:recv_timeout, @connection_timeout}])

    response
  end

  def post_token(url, headers, data_map) do
    headers = headers ++ @default_headers
    # ++ [{:proxy, "127.0.0.1:8888"}]
    {:ok, response} =
      HTTPoison.post(url, data_map, headers, [{:recv_timeout, @connection_timeout}])

    response
  end

  def delete(url, headers) do
    headers = headers ++ @default_headers
    # ++ [{:proxy, "127.0.0.1:8888"}]
    {:ok, response} =
      HTTPoison.delete(url, headers, [
        {:recv_timeout, @connection_timeout}
      ])

    response
  end

  def post_multipart(url, headers, path_to_file, name) do
    headers = headers ++ @default_headers

    # The Xero Files API grabs the filename out of the content-disposition header of the multipart file request.
    # Hackney sets this to be the filename from the path of the file. We need to override it
    content_disposition_overload = "form-data; filename=\"" <> name <> "\""

    # ++ [{:proxy, "127.0.0.1:8888"}]
    {:ok, response} =
      HTTPoison.post(
        url,
        {:multipart,
         [{:file, path_to_file, [{"Content-Disposition", content_disposition_overload}]}]},
        headers,
        [{:recv_timeout, @connection_timeout}]
      )

    handle_response(response)
  end

  def post_file(url, headers, path_to_file) do
    headers = headers ++ @default_headers
    # ++ [{:proxy, "127.0.0.1:8888"}]
    {:ok, response} =
      HTTPoison.post(url, {:file, path_to_file}, headers, [{:recv_timeout, @connection_timeout}])

    response
  end

  # possibly used by files beta. CoreAPI does not use after including Ecto.Schema
  defp handle_response(response) do
    headers = response.headers |> Map.new()
    content_type = headers["Content-Type"]

    case content_type do
      nil -> handle_html_response(response)
      _ -> handle_response(response, content_type)
    end
  end

  # possibly used by files beta. CoreAPI does not use after including Ecto.Schema
  defp handle_response(response, content_type) do
    content_type = String.split(content_type, " ") |> Enum.at(0)

    case content_type do
      "application/json;" -> handle_json_response(response)
      _ -> handle_html_response(response)
    end
  end

  # possibly used by files beta. CoreAPI does not use after including Ecto.Schema
  defp handle_json_response(response) do
    resp = %{"http_status_code" => response.status_code}

    {_, parsed} = Jason.decode(response.body)
    Map.merge(resp, parsed)
  end

  # possibly used by files beta. CoreAPI does not use after including Ecto.Schema
  defp handle_html_response(response) do
    resp = %{"http_status_code" => response.status_code}
    URI.decode_query(response.body) |> Map.merge(resp)
  end
end
