defmodule XeroXero.Utils.Oauth do
  def oauth_consumer_key do
    Application.get_env(:xeroxero, :consumer_key)
  end

  def oauth_consumer_secret do
    Application.get_env(:xeroxero, :consumer_secret)
  end

  def application_type do
    Application.get_env(:xeroxero, :app_type)
  end

  def private_key do
    Application.get_env(:xeroxero, :private_key_path)
  end

  def create_auth_header(method, url, additional_params, token) do
    {base_string, oauth_params} = create_oauth_context(method, url, additional_params)

    signature = sign(base_string, token)

    "OAuth oauth_signature=\"" <>
      signature <> "\", " <> XeroXero.Utils.Helpers.join_params_keyword(oauth_params, :auth_header)
  end

  def create_auth_header(method, url, additional_params) do
    {base_string, oauth_params} = create_oauth_context(method, url, additional_params)

    signature = sign(base_string)

    "OAuth oauth_signature=\"" <>
      signature <> "\", " <> XeroXero.Utils.Helpers.join_params_keyword(oauth_params, :auth_header)
  end

  defp create_oauth_context(method, url, additional_params) do
    timestamp =
      :erlang.float_to_binary(Float.floor(:os.system_time(:milli_seconds) / 1000), [
        {:decimals, 0}
      ])

    oauth_signing_params = [
      oauth_consumer_key: additional_params[:oauth_token],
      oauth_nonce: XeroXero.Utils.Helpers.random_string(10),
      oauth_signature_method: signature_method(),
      oauth_version: "1.0",
      oauth_timestamp: timestamp
    ]

    params = additional_params ++ oauth_signing_params

    uri_parts = String.split(url, "?")
    url = Enum.at(uri_parts, 0)

    params_with_extras =
      if length(uri_parts) > 1 do
        query_params =
          Enum.at(uri_parts, 1)
          |> URI.decode_query()
          |> Enum.map(fn {key, value} ->
            {String.to_atom(key), URI.encode_www_form(value) |> String.replace("+", "%20")}
          end)

        params ++ query_params
      else
        params
      end

    params_with_extras = Enum.sort(params_with_extras)

    base_string =
      method <>
        "&" <>
        URI.encode_www_form(url) <>
        "&" <>
        URI.encode_www_form(
          XeroXero.Utils.Helpers.join_params_keyword(params_with_extras, :base_string)
        )

    {base_string, params}
  end

  def sign(base_string) do
    rsa_sha1_sign(base_string)
  end

  def sign(base_string, token) do
    hmac_sha1_sign(base_string, token)
  end

  defp signature_method() do
    case(application_type()) do
      :private -> "RSA-SHA1"
      :public -> "HMAC-SHA1"
      :partner -> "RSA-SHA1"
    end
  end

  defp rsa_sha1_sign(base_string) do
    hashed = :crypto.hash(:sha, base_string)

    {:ok, body} = File.read(private_key())

    [decoded_key] = :public_key.pem_decode(body)
    key = :public_key.pem_entry_decode(decoded_key)
    signed = :public_key.encrypt_private(hashed, key)
    URI.encode(Base.encode64(signed), &URI.char_unreserved?(&1))
  end

  defp hmac_sha1_sign(base_string, token) do
    key =
      case(token) do
        nil -> oauth_consumer_secret() <> "&"
        _ -> oauth_consumer_secret() <> "&" <> token["oauth_token_secret"]
      end

    signed = :crypto.mac(:hmac, :sha, key, base_string)
    URI.encode(Base.encode64(signed), &URI.char_unreserved?(&1))
  end
end
