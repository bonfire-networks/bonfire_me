if Application.compile_env(:bonfire_me, :modularity) != :disabled do
  defmodule Bonfire.Me.Web.MastoAccountController do
    @moduledoc "Mastodon-compatible Account endpoints (users, profiles, relationships)"

    use Bonfire.UI.Common.Web, :controller

    alias Bonfire.Me.API.GraphQLMasto.Adapter
    alias Bonfire.Boundaries.API.GraphQLMasto.Adapter, as: BoundariesAdapter

    def show(conn, %{"id" => "verify_credentials"} = _params), do: Adapter.me(conn)

    def show(conn, %{"id" => id} = _params),
      do: Adapter.user(%{"filter" => %{"id" => id}}, conn)

    def show(conn, params), do: Adapter.user(params, conn)

    def verify_credentials(conn, params), do: Adapter.me(params, conn)
    def update_credentials(conn, params), do: Adapter.update_credentials(params, conn)
    def show_preferences(conn, params), do: Adapter.get_preferences(params, conn)

    def mutes(conn, params), do: BoundariesAdapter.mutes(params, conn)
    def blocks(conn, params), do: BoundariesAdapter.blocks(params, conn)

    def relationships(conn, params), do: Adapter.relationships(params, conn)
    def search(conn, params), do: Adapter.search_accounts(params, conn)
    def lookup(conn, params), do: Adapter.lookup_account(params, conn)

    def followers(conn, %{"id" => id} = params), do: Adapter.followers(id, params, conn)
    def following(conn, %{"id" => id} = params), do: Adapter.following(id, params, conn)

    def follow(conn, %{"id" => id}), do: Adapter.follow_account(%{"id" => id}, conn)
    def unfollow(conn, %{"id" => id}), do: Adapter.unfollow_account(%{"id" => id}, conn)
    def mute(conn, %{"id" => id}), do: BoundariesAdapter.mute_account(%{"id" => id}, conn)
    def unmute(conn, %{"id" => id}), do: BoundariesAdapter.unmute_account(%{"id" => id}, conn)
    def block(conn, %{"id" => id}), do: BoundariesAdapter.block_account(%{"id" => id}, conn)
    def unblock(conn, %{"id" => id}), do: BoundariesAdapter.unblock_account(%{"id" => id}, conn)

    def follow_requests(conn, params), do: Adapter.follow_requests(params, conn)
    def follow_requests_outgoing(conn, params), do: Adapter.follow_requests_outgoing(params, conn)

    def authorize_follow_request(conn, %{"account_id" => id}),
      do: Adapter.authorize_follow_request(id, conn)

    def reject_follow_request(conn, %{"account_id" => id}),
      do: Adapter.reject_follow_request(id, conn)

    def suggestions(conn, params), do: Adapter.suggestions(params, conn)

    def familiar_followers(conn, params), do: Adapter.familiar_followers(params, conn)

    def delete_avatar(conn, params), do: Adapter.delete_avatar(params, conn)
    def delete_header(conn, params), do: Adapter.delete_header(params, conn)
    def delete_account(conn, params), do: Adapter.delete_account(params, conn)

    def alias_account(conn, params), do: Adapter.alias_account(params, conn)
    def move_account(conn, params), do: Adapter.move_account(params, conn)
  end
end
