defmodule Bonfire.Me.Identity.Characters do

  alias Bonfire.Data.Identity.Character
  alias Ecto.Changeset
  alias Pointers.Changesets
  import Bonfire.Me.Integration

  @username_regex ~r(^[a-z][a-z0-9_]{2,30}$)i

  def changeset(char \\ %Character{}, params) do
    char
    |> Character.changeset(params)
    |> Changeset.validate_format(:username, @username_regex)
    |> Changesets.replicate_map_valid_change(:username, :username_hash, &Character.hash/1)
  end

end
