if Application.compile_env(:bonfire_api_graphql, :modularity) != :disabled do
  defmodule Bonfire.Me.Web.MastoSignupController do
    @moduledoc """
    Mastodon-compatible account registration endpoint.

    Implements POST /api/v1/accounts for in-app signup without OAuth redirect flow.
    Also handles POST /api/v1/emails/confirmations for resending confirmation emails.
    """
    use Bonfire.UI.Common.Web, :controller

    alias Bonfire.Me.API.GraphQLMasto.Adapter

    def create(conn, params), do: Adapter.signup(params, conn)

    def resend_confirmation(conn, params), do: Adapter.resend_confirmation(params, conn)
  end
end
