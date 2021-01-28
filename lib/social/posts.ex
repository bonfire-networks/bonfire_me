defmodule Bonfire.Me.Social.Posts do

  alias Bonfire.Data.Social.{Post, PostContent}
  alias Ecto.Changeset
  import Ecto.Query

  import Bonfire.Me.Integration

  def create(creator, attrs) do
    attrs = Map.put(attrs, :created, %{creator_id: creator.id})
    repo().put(changeset(:create, attrs))
  end

  def changeset(:create, attrs) do
    Post.changeset(%Post{}, attrs)
    |> Changeset.cast_assoc(:post_content)
    |> Changeset.cast_assoc(:created)
  end

  def by_user(user_id) do
    repo().all(by_user_query(user_id))
  end

  def by_user_query(user_id) do
    from p in Post,
     join: pc in assoc(p, :post_content),
     join: cr in assoc(p, :created),
     where: cr.creator_id == ^user_id,
     preload: [post_content: pc, created: cr]
  end
end
