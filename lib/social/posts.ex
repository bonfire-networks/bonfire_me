defmodule Bonfire.Me.Social.Posts do

  alias Bonfire.Data.Social.{Post, PostContent}
  alias Pointers.Changesets

  defp repo, do: Application.get_env(:bonfire_me, :repo_module)

  def create(creator, attrs) do
    attrs = Map.put(attrs, :creator_id, creator.id)
    repo().put(changeset(:create, attrs))
  end

  def changeset(:create, attrs) do
    Post.changeset(%Post{}, attrs)
    |> Changesets.cast_assoc(:post_content, attrs)
    |> Changesets.cast_assoc(:created, attrs)
  end

end
