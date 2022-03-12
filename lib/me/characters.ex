defmodule Bonfire.Me.Characters do

  alias Bonfire.Data.Identity.Character
  alias Ecto.Changeset
  alias Bonfire.Common.Utils
  alias Bonfire.Common.URIs
  import Bonfire.Me.Integration
  import Ecto.Query
  use Arrows

  def context_module, do: Character

  @username_max_length 62
  @username_forbidden ~r/[^a-z0-9_]+/i
  @username_regex ~r(^[a-z0-9_]{2,63}$)i

  def by_username(username) when is_binary(username), do: by_username_q(username) |> repo().single()
  def get(ids) when is_list(ids), do: {:ok, q_by_id(ids) |> repo().many()}
  def get(id), do: q_by_id(id) |> repo().single()

  def by_username_q(username) do
    from c in Character,
      left_join: p in assoc(c, :profile),
      left_join: pe in assoc(c, :peered),
      left_join: a in assoc(c, :actor),
      where: c.username == ^username,
      preload: [peered: pe, profile: p, actor: a]
  end

  def q_by_id(ids) when is_list(ids) do
    from c in Character,
      left_join: p in assoc(c, :profile),
      left_join: pe in assoc(c, :peered),
      left_join: a in assoc(c, :actor),
      where: c.id in ^ids,
      preload: [peered: pe, profile: p, actor: a]
  end

  def q_by_id(id) do
    from c in Character,
      left_join: p in assoc(c, :profile),
      left_join: pe in assoc(c, :peered),
      left_join: a in assoc(c, :actor),
      where: c.id == ^id,
      preload: [peered: pe, profile: p, actor: a]
  end

  def username_available?(username) do
    not repo().exists?(from c in Character, where: c.username == ^username) and hash_available?(Character.hash(username))
  end

  def hash_available?(hash) do
    not repo().exists?(from c in Character, where: c.username_hash == ^hash)
  end

  def hash_delete(hash) do
    repo().delete_all(from c in Character, where: c.username_hash == ^hash)
  end


  def remote_changeset(char, params), do: do_remote_changeset(char, params)

  def clean_username(username) do
    Regex.replace(@username_forbidden, username, "_")
    |> String.slice(0..(@username_max_length-1))
    |> String.trim("_")
  end

  def changeset(char \\ %Character{}, params, profile \\ :local) do
    case char.__meta__.state do
      :built ->
        char
        |> Character.changeset(params, :hash)
        |> Changeset.validate_format(:username, @username_regex)
        |> changeset_common()
      :loaded ->
        char = repo().maybe_preload(char, [:actor, :outbox, :inbox, :notifications])
        if Utils.e(char, :actor, nil) do
          %{"actor" => %{"id"=> Utils.e(char, :actor, :id, nil)}}
          |> Map.merge(params, ..., fn _, a, b -> Map.merge(a, b) end)
        else
          params
        end
        |> Utils.input_to_atoms()
        |> Character.changeset(char, ..., :update)
        |> changeset_common()
      :deleted ->
        raise RuntimeError, message: "deletion unimplemented"
    end
  end

  defp changeset_common(changeset) do
    changeset
    |> Changeset.update_change(:username, &clean_username/1)
    |> Changeset.validate_format(:username, @username_regex)
    |> Changeset.cast_assoc(:actor)
  end

  defp do_changeset(char \\ %Character{}, params)

  defp do_changeset(%Character{} = char, params) do
  end

  defp do_remote_changeset(%Character{id: _} = char, params) do # update
    char
    |> Character.changeset(params, :hash)
    |> Changeset.cast_assoc(:actor)
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

  def display_username(user, is_local? \\ nil)

  def display_username("@"<>username, is_local?) do
    display_username(username, is_local?)
  end
  def display_username(username, true) when is_binary(username) do
    "@#{username}@#{URIs.instance_domain()}"
  end
  def display_username(username, false) when is_binary(username) do
    "@"<>username
  end
  def display_username(%{username: username} = character, _) when not is_nil(username) do
    display_username(username, is_local?(character))
  end
  def display_username(%{display_username: username}, is_local?) when not is_nil(username) do
    display_username(username, is_local?)
  end
  def display_username(%{character: _} = thing, _) do
    repo().maybe_preload(thing, [character: :peered])
    display_username(Map.get(thing, :character), is_local?(thing))
  end
  def display_username(_, _) do
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

  def indexing_object_format(%{character: obj}), do: indexing_object_format(obj)
  def indexing_object_format(%Character{id: _} = obj) do

    %{

      "index_type" => "Bonfire.Data.Identity.Character",
      "username" => obj.username,
      "url" => character_url(obj),
   }
  end

  def indexing_object_format(_), do: nil


end
