defmodule Bonfire.Me.Identity.Characters do

  alias Bonfire.Data.Identity.Character
  alias Ecto.Changeset
  alias Pointers.Changesets
  import Bonfire.Me.Integration

  @username_forbidden ~r/[^a-z0-9_]+/i
  @username_regex ~r(^[a-z][a-z0-9_]{2,30}$)i

  def changeset(char \\ %Character{}, %{"username" => username} = params) when is_binary(username) do
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

  defp clean_username(username) do
    Regex.replace(@username_forbidden, username, "_") |> String.slice(0..29)
  end

  defp do_changeset(char \\ %Character{}, params) do
    char
    |> Character.changeset(params, :hash)
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
