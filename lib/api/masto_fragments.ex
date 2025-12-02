if Application.compile_env(:bonfire, :modularity) != :disabled and
     Application.compile_env(:bonfire_api_graphql, :modularity) != :disabled do
  defmodule Bonfire.Me.API.MastoFragments do
    @moduledoc "GraphQL fragments for Mastodon API user/account mapping."

    @user_profile """
      id
      created_at: date_created
      profile {
        avatar: icon
        avatar_static: icon
        header: image
        header_static: image
        display_name: name
        note: summary
        website
      }
      character {
        username
        acct: username
        url: canonical_uri
        peered {
          canonical_uri
        }
      }
    """

    def user_profile, do: @user_profile
  end
end
