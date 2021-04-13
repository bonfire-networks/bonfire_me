defmodule Bonfire.Me.Characters do

  alias Bonfire.Data.Identity.Character
  alias Ecto.Changeset
  import Bonfire.Me.Integration
  import Ecto.Query

  @username_forbidden ~r/[^a-z0-9_]+/i
  @username_regex ~r(^[a-z][a-z0-9_]{2,30}$)i

  def by_username(username) when is_binary(username), do: by_username_q(username)
  def get(id), do: q_by_id(id)

  def by_username_q(username) do
    from c in Character,
      left_join: p in assoc(c, :profile),
      left_join: u in assoc(c, :user),
      left_join: a in assoc(c, :actor),
      left_join: ia in assoc(u, :instance_admin),
      where: c.username == ^username,
      preload: [instance_admin: ia, profile: p, character: c, actor: a]
  end
  def q_by_id(id) do
    from c in Character,
      left_join: p in assoc(c, :profile),
      left_join: u in assoc(c, :user),
      left_join: a in assoc(c, :actor),
      left_join: ia in assoc(u, :instance_admin),
      where: c.id == ^id,
      preload: [instance_admin: ia, profile: p, character: c, actor: a]
  end

  def changeset(char \\ %Character{}, params)

    def changeset(char, %{"username" => username} = params) when is_binary(username) do
    do_changeset(
      char,
      Map.put(params, "username", clean_username(username))
    )
  end

  def changeset(char, %{username: username} = params) when is_binary(username) do
    do_changeset(
      char,
      Map.put(params, :username, clean_username(username))
    )
  end

  def changeset(char, params), do: do_changeset(char, params)

  def remote_changeset(char, params), do: do_remote_changeset(char, params)

  defp clean_username(username) do
    Regex.replace(@username_forbidden, username, "_") |> String.slice(0..29)
  end

  defp do_changeset(char \\ %Character{}, params)

  defp do_changeset(%Character{id: _} = char, params) do # update
    char
    |> Character.changeset(params, :hash)
    |> Changeset.validate_format(:username, @username_regex)
  end

  defp do_changeset(%Character{} = char, params) do # create
    char
    |> Character.changeset(params, :hash)
    |> Changeset.validate_format(:username, @username_regex)
    |> Changeset.cast(%{
      # feed: %{},
      follow_count: %{follower_count: 0, followed_count: 0},
    }, [])
    # |> Changeset.cast_assoc(:feed)
    |> Changeset.cast_assoc(:follow_count)
  end

  defp do_remote_changeset(%Character{id: _} = char, params) do # update
    char
    |> Character.changeset(params, :hash)
  end

  defp do_remote_changeset(%Character{} = char, params) do # create
    char
    |> Character.changeset(params, :hash)
    |> Changeset.cast(%{
      # feed: %{},
      follow_count: %{follower_count: 0, followed_count: 0},
    }, [])
    # |> Changeset.cast_assoc(:feed)
    |> Changeset.cast_assoc(:follow_count)
  end

  def display_username(%{username: username}) when not is_nil(username) do
    "@" <> username
  end

  def display_username(%{character: _} = thing) do
    repo().maybe_preload(thing, :character)
    display_username(Map.get(thing, :character))
  end

  def display_username(_) do
    nil
  end

  def character_url(username) when is_binary(username) do
    ap_base_path = Bonfire.Common.Config.get(:ap_base_path, "/pub")
    domain = Bonfire.Common.URIs.base_url()
    domain <> ap_base_path <> "/actors/" <> username
  end

  def character_url(%{username: username}) when not is_nil(username) do
    character_url(username)
  end

  def character_url(%{character: _} = thing) do
    repo().maybe_preload(thing, :character)
    character_url(Map.get(thing, :character))
  end

  def character_url(_) do
    nil
  end

end
