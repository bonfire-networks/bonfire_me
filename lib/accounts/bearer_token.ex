defmodule Bonfire.Me.Auth.BearerToken do
  @moduledoc """
  Issues and verifies signed Phoenix.Token bearer tokens.

  Uses `Phoenix.Token.sign/verify` (HMAC-signed, payload readable but tamper-proof).
  Callers must supply their own `:salt` to namespace tokens and avoid collisions between
  token types (e.g. API bearer vs iframe embed).
  """

  @doc "Issue a signed bearer token. Requires `salt:` option."
  def sign(ids, opts) do
    Phoenix.Token.sign(endpoint(), salt!(opts), ids)
  end

  @doc """
  Verify a bearer token. Requires `salt:` option.

  Pass `max_age: seconds` to enforce expiry, or omit for no expiry (default).
  """
  def verify(token, opts) do
    max_age = Keyword.get(opts, :max_age, :infinity)
    Phoenix.Token.verify(endpoint(), salt!(opts), token, max_age: max_age)
  end

  defp salt!(opts), do: Keyword.fetch!(opts, :salt)

  defp endpoint, do: Bonfire.Common.Config.endpoint_module()
end
