defmodule Bonfire.Me.Social.Profiles do

  alias Bonfire.Data.Social.Profile
  alias Ecto.Changeset
  alias Pointers.Changesets
  import Bonfire.Me.Integration

  @username_regex ~r(^[a-z][a-z0-9_]{2,30}$)i

  def changeset(profile \\ %Profile{}, params) do
    profile
    |> Profile.changeset(params)
    |> Changeset.validate_length(:name, min: 4, max: 50)
    |> Changeset.validate_length(:summary, min: 0, max: 1024)
  end

end
