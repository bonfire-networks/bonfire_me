defmodule Bonfire.Me.Characters do
  use Bonfire.Common.Utils
  alias Bonfire.Data.Identity.Character
  alias Bonfire.Common.URIs
  alias Bonfire.Common.Types

  alias Ecto.Changeset
  alias Pointers.Changesets
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

  def by_username(username) when is_binary(username),
    do: by_username_q(username) |> repo().single()

  def by_username!(username) when is_binary(username),
    do: by_username_q(username) |> repo().one()

  def get(ids) when is_list(ids), do: {:ok, q_by_id(ids) |> repo().many()}

  def get(id) when is_binary(id) do
    if is_ulid?(id) do
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

  def username_available?(username) do
    not repo().exists?(from(c in Character, where: c.username == ^username)) and
      hash_available?(Character.hash(username))
  end

  def hash_available?(hash) do
    not repo().exists?(from(c in Character, where: c.username_hash == ^hash))
  end

  def hash_delete(hash) do
    repo().delete_all(from(c in Character, where: c.username_hash == ^hash))
  end

  def clean_username(username) do
    Regex.replace(@username_forbidden, username, "_")
    |> String.slice(0..(@username_max_length - 1))
    |> String.trim("_")
  end

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
    |> debug("FIXME: why is actor not being cast?")

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
    "#{prefix || "@"}#{username}@#{URIs.instance_domain()}"
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

  def character_mention_prefix(object) do
    case Types.object_type(object) do
      Bonfire.Data.Identity.User -> "@"
      Bonfire.Classify.Category -> "+"
      Bonfire.Tag.Hashtag -> "#"
      _ -> "@"
    end
  end

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
      "index_type" => "Bonfire.Data.Identity.Character",
      "username" => obj.username,
      "url" => character_url(obj)
    }
  end

  def indexing_object_format(_), do: nil
end
