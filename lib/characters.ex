defmodule Bonfire.Me.Characters do

  alias Bonfire.Data.Identity.Character
  alias Bonfire.Common.{URIs, Utils, Types}
  alias Ecto.Changeset
  alias Pointers.Changesets
  import Bonfire.Me.Integration
  import Ecto.Query
  import EctoSparkles
  import Untangle
  use Arrows

  def context_module, do: Character

  @username_max_length 62
  @username_forbidden ~r/[^a-z0-9_]+/i
  @username_regex ~r(^[a-z0-9_]{2,63}$)i

  def by_username(username) when is_binary(username), do: by_username_q(username) |> repo().single()
  def get(ids) when is_list(ids), do: {:ok, q_by_id(ids) |> repo().many()}
  def get(id), do: q_by_id(id) |> repo().single()

  def by_username_q(username) do
    from(c in Character, where: c.username == ^username)
    |> proload([:profile, :peered, :actor])
  end

  def q_by_id(ids) do
    from(c in Character, where: c.id in ^List.wrap(ids))
    |> proload([:peered, :profile, :actor])
  end

  def username_available?(username) do
    not repo().exists?(from c in Character, where: c.username == ^username)
    and hash_available?(Character.hash(username))
  end

  def hash_available?(hash) do
    not repo().exists?(from c in Character, where: c.username_hash == ^hash)
  end

  def hash_delete(hash) do
    repo().delete_all(from c in Character, where: c.username_hash == ^hash)
  end

  def clean_username(username) do
    Regex.replace(@username_forbidden, username, "_")
    |> String.slice(0..(@username_max_length-1))
    |> String.trim("_")
  end

  def changeset(char \\ %Character{}, params, _profile \\ :local) do
    case Changeset.cast(char, %{}, []).data.__meta__.state do
      :built ->
        char
        |> Character.changeset(params, :hash)
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

  def remote_changeset(char, params), do: do_remote_changeset(char, params)

  defp do_remote_changeset(changeset, params) do
    # If it's a character, turn it into a changeset
    changeset = Changesets.cast(changeset, %{}, [])
    if is_binary(changeset.data.id) do
      changeset # update
      |> Character.changeset(params, :hash)
      |> Changeset.cast_assoc(:feed)
      |> Changeset.cast_assoc(:follow_count)
    else
      changeset # insert
      |> Character.changeset(params, :hash)
      |> Changeset.cast_assoc(:actor)
    end
  end

  def display_username(user, always_include_domain \\ false, is_local? \\ nil, prefix \\ nil)

  def display_username("@"<>username, always_include_domain, is_local?, _) do
    display_username(username, always_include_domain, is_local?, "@")
  end
  def display_username(username, true, true, prefix) when is_binary(username) do
    "#{prefix || "@"}#{username}@#{URIs.instance_domain()}"
  end
  def display_username(username, _, _, prefix) when is_binary(username) do
    "#{prefix || "@"}#{username}"
  end
  def display_username(%{username: username} = character, always_include_domain, _, prefix) when not is_nil(username) do
    display_username(username, always_include_domain, (if always_include_domain, do: is_local?(character)), prefix || character_mention_prefix(character))
  end
  def display_username(%{display_username: username} = thing, always_include_domain, is_local?, prefix) when not is_nil(username) do
    display_username(username, always_include_domain, (if always_include_domain, do: is_local?), prefix || character_mention_prefix(thing))
  end
  def display_username(%{character: _} = thing, always_include_domain, _, prefix) do
    repo().maybe_preload(thing, [character: :peered])
    display_username(Map.get(thing, :character), always_include_domain, (if always_include_domain, do: is_local?(thing)), prefix || character_mention_prefix(thing))
  end
  def display_username(_, _, _, _) do
    nil
  end

  def character_mention_prefix(object) do
    case Types.object_type(object) do
      Bonfire.Data.Identity.User -> "@"
      Bonfire.Classify.Category -> "+"
      Bonfire.Tag.Hashtag -> "#"
      _ -> "@"
    end
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

  def character_url(other) do
    warn(other, "Dunno how to handle")
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
