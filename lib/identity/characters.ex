defmodule Bonfire.Me.Identity.Characters do

  alias Bonfire.Data.Identity.Character
  alias Ecto.Changeset
  alias Pointers.Changesets
  import Bonfire.Me.Integration

  @username_forbidden ~r/[^a-z0-9_]+/i
  @username_regex ~r(^[a-z][a-z0-9_]{2,30}$)i

  def changeset(char \\ %Character{}, params) do

    char
    |> Character.changeset(params, :hash)
    |> Changeset.cast(%{username: Regex.replace(@username_forbidden, Map.get(params, :username), "_")}, [:username])
    |> Changeset.validate_format(:username, @username_regex)
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
    endpoint = Bonfire.Common.Config.get!(:endpoint_module)
    ap_base_path = Bonfire.Common.Config.get(:ap_base_path, "/pub")
    endpoint.url() <> ap_base_path <> "/actors/" <> username
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
