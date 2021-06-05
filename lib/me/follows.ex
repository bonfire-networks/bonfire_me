defmodule Bonfire.Me.Follows do
  alias Bonfire.Data.Identity.User

  @doc """
  handle a user following another user
  """
  def follow(%User{}=follower, %User{}=followed) do
    Bonfire.Social.Follows.create(follower, followed)
  end

end
