defmodule Bonfire.Me.Social.Posts do

  alias Bonfire.Data.Social.{Post, PostContent}
  alias Pointers.Changesets

  defp repo, do: Application.get_env(:bonfire_me, :repo_module)

  def create(creator, attrs) do
    repo().put(changeset(:create, creator, attrs))
  end

  def changeset(:create, creator, attrs) do
    Post.changeset(%Post{}, attrs)
    |> Changesets.cast_assoc(:post_content, attrs)
  end

end
