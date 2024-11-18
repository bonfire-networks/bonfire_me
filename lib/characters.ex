defmodule Bonfire.Me.Characters do
  @moduledoc """
  Shared helpers for character types (such as User or Category)

  Context for `Bonfire.Data.Identity.Character` mixin, which has these fields:
  - username
  - username_hash: hashed username (used for preserving uniqueness incl. deleted usernames)
  - outbox: Feed of activities by the user
  - inbox: Feed of messages and other activities for the user
  - notifications: Feed of notifications for the user
  """

  use Bonfire.Common.Utils
  alias Bonfire.Data.Identity.Character
  alias Bonfire.Common.URIs
  alias Bonfire.Common.Types

  alias Ecto.Changeset
  alias Needle.Changesets
  import Bonfire.Me.Integration
  import Ecto.Query
  import EctoSparkles
  # import Untangle
  use Arrows

  @behaviour Bonfire.Common.ContextModule
  @behaviour Bonfire.Common.QueryModule
  def schema_module, do: Character

  @username_max_length 62
  @username_forbidden ~r/[^a-z0-9_]+/i
  @username_regex ~r(^[a-z0-9_]{2,63}$)i

  @doc """
  Retrieves a character by username.

  ## Examples

      > Bonfire.Me.Characters.by_username("username")
      %Bonfire.Data.Identity.Character{}
  """
  def by_username(username) when is_binary(username),
    do: by_username_q(username) |> repo().single()

  def by_username!(username) when is_binary(username),
    do: by_username_q(username) |> repo().one()

  @doc """
  Retrieves multiple characters by IDs.

  ## Examples

      > Bonfire.Me.Characters.get("id_or_username")
      %Bonfire.Data.Identity.Character{}

      > Bonfire.Me.Characters.get(["id1", "id2"])
      {:ok, [%Bonfire.Data.Identity.Character{}, %Bonfire.Data.Identity.Character{}]}
  """
  def get(ids) when is_list(ids), do: {:ok, q_by_id(ids) |> repo().many()}

  def get(id) when is_binary(id) do
    if is_uid?(id) do
      q_by_id(id)
    else
      by_username_q(id)
    end
    |> repo().single()
  end

  def by_username_q(username) do
    from(c in Character, where: c.username == ^username)
    |> proload([:profile, :peered, :actor])
  end

  def q_by_id(ids) do
    from(c in Character, where: c.id in ^List.wrap(ids))
    |> proload([:peered, :profile, :actor])
  end

  @doc """
  Checks if a username is available.

  ## Examples

      iex> Bonfire.Me.Characters.username_available?("non_existing_username")
      true
  """
  def username_available?(username) do
    not repo().exists?(from(c in Character, where: c.username == ^username)) and
      hash_available?(Character.hash(username))
  end

  @doc """
  Checks if a username hash is available.

  ## Examples

      iex> Bonfire.Me.Characters.hash_available?("hash")
      true
  """
  def hash_available?(hash) do
    not repo().exists?(from(c in Character, where: c.username_hash == ^hash))
  end

  @doc """
  Deletes a character by username hash.

  ## Examples

      > Bonfire.Me.Characters.hash_delete("hash")
  """
  def hash_delete(hash) do
    repo().delete_all(from(c in Character, where: c.username_hash == ^hash))
  end

  @doc """
  Cleans a username by replacing forbidden characters with underscores.

  ## Examples

      iex> Bonfire.Me.Characters.clean_username("invalid username!")
      "invalid_username"
  """
  def clean_username(username) do
    Regex.replace(@username_forbidden, username, "_")
    |> String.slice(0..(@username_max_length - 1))
    |> String.trim("_")
  end

  @doc """
  Updates a character with the given attributes.

  ## Examples

      > Bonfire.Me.Characters.update(%Bonfire.Data.Identity.Character{}, %{field: "value"})
      {:ok, %Bonfire.Data.Identity.Character{}}
  """
  def update(%Character{} = character, attrs) do
    repo().update(changeset(character, attrs, :update))
  end

  def changeset(char \\ %Character{}, params, _profile \\ :local) do
    case Changeset.cast(char, %{}, []).data.__meta__.state |> debug("cs_state") do
      :built ->
        char
        |> Character.changeset(params, :hash)
        |> changeset_common()

      :loaded ->
        # , :outbox, :inbox, :notifications]
        char = repo().maybe_preload(char, [:actor])

        params
        |> Enums.input_to_atoms()
        |> Character.changeset(char, ..., :update)
        |> changeset_common()

      :deleted ->
        raise RuntimeError, message: "deletion unimplemented"
    end

    # |> debug("char cs")
  end

  defp changeset_common(changeset) do
    changeset
    |> Changeset.update_change(:username, &clean_username/1)
    |> Changeset.validate_format(:username, @username_regex)
    |> Changesets.cast_assoc(:actor)
  end

  def remote_changeset(changeset, params) do
    # If it's a character, turn it into a changeset
    changeset = Changesets.cast(changeset, %{}, [])

    if is_binary(changeset.data.id) do
      # update
      changeset
      |> Character.changeset(params, :update)
      |> Changeset.cast_assoc(:feed)
      |> Changeset.cast_assoc(:follow_count)
      |> Changeset.cast_assoc(:actor)
    else
      # insert
      changeset
      |> Character.changeset(params, :hash)
      |> Changeset.cast_assoc(:actor)
    end
    |> debug("FIXME: why is actor not being cast?")

    # |> info()
  end

  @doc """
  Displays a username with optional domain and prefix.

  ## Examples

      iex> Bonfire.Me.Characters.display_username("username")
      "@username"

      iex> Bonfire.Me.Characters.display_username("username", true, true, "@")
      "@username@domain.com"
  """
  def display_username(
        user,
        always_include_domain \\ false,
        is_local? \\ nil,
        prefix \\ nil
      )

  def display_username("@" <> username, always_include_domain, is_local?, _) do
    display_username(username, always_include_domain, is_local?, "@")
  end

  def display_username(username, true, true, prefix) when is_binary(username) do
    "#{prefix || "@"}#{username}@#{URIs.base_domain()}"
  end

  def display_username(username, _, _, prefix) when is_binary(username) do
    "#{prefix || "@"}#{username}"
  end

  def display_username(%{type: :group} = thing, always_include_domain, is_local?, nil) do
    display_username(thing, always_include_domain, is_local?, "&")
  end

  def display_username(%{type: :topic} = thing, always_include_domain, is_local?, nil) do
    display_username(thing, always_include_domain, is_local?, "+")
  end

  def display_username(%{__schema__: schema} = thing, always_include_domain, is_local?, nil)
      when schema == Bonfire.Classify.Category do
    display_username(thing, always_include_domain, is_local?, "+")
  end

  def display_username(
        %{username: username} = character,
        always_include_domain,
        _,
        prefix
      )
      when not is_nil(username) do
    display_username(
      username,
      always_include_domain,
      if(always_include_domain, do: is_local?(character)),
      prefix || character_mention_prefix(character)
    )
  end

  def display_username(
        %{display_username: username} = thing,
        always_include_domain,
        is_local?,
        prefix
      )
      when not is_nil(username) do
    display_username(
      username,
      always_include_domain,
      if(always_include_domain, do: is_local?),
      prefix || character_mention_prefix(thing)
    )
  end

  def display_username(
        %{character: _} = thing,
        always_include_domain,
        _,
        prefix
      ) do
    display_username(
      Map.get(thing, :character),
      always_include_domain,
      if(always_include_domain, do: is_local?(thing)),
      prefix || character_mention_prefix(thing)
    )
  end

  def display_username(_, _, _, _) do
    nil
  end

  @doc """
  Returns the appropriate mention prefix for a character type.

  ## Examples

      iex> Bonfire.Me.Characters.character_mention_prefix(%Bonfire.Data.Identity.User{})
      "@"
  """
  def character_mention_prefix(object) do
    case Types.object_type(object) do
      Bonfire.Data.Identity.User -> "@"
      Bonfire.Classify.Category -> "+"
      Bonfire.Tag.Hashtag -> "#"
      _ -> "@"
    end
  end

  @doc """
  Returns the canonical URL for a character.

  ## Examples

      iex> Bonfire.Me.Characters.character_url(%Bonfire.Data.Identity.Character{})
      "http://example.com/character/username"
  """
  def character_url(character), do: URIs.canonical_url(character)

  # def character_url(username) when is_binary(username) do
  #   ap_base_path = Bonfire.Common.Config.get(:ap_base_path, "/pub")
  #   domain = Bonfire.Common.URIs.base_url()
  #   domain <> ap_base_path <> "/actors/" <> username
  # end

  # def character_url(%{username: username}) when not is_nil(username) do
  #   character_url(username)
  # end

  # def character_url(%{character: _} = thing) do
  #   repo().maybe_preload(thing, :character)
  #   character_url(Map.get(thing, :character))
  # end

  # def character_url(other) do
  #   warn(other, "Dunno how to handle")
  #   nil
  # end

  def indexing_object_format(%{character: obj}), do: indexing_object_format(obj)

  def indexing_object_format(%Character{id: _} = obj) do
    %{
      "index_type" => Types.module_to_str(Character),
      "username" => obj.username,
      "url" => character_url(obj)
    }
  end

  def indexing_object_format(_), do: nil
end
