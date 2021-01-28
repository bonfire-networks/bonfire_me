defmodule Bonfire.Me.Users.Follows do
  alias Bonfire.Data.Identity.User

  @doc """
  handle a user following another user
  """
  def follow(%User{}=follower, %User{}=followed) do
    Bonfire.Me.Social.Follows.create(follower, followed)
  end

end
