defmodule Bonfire.Me.Profiles do

  alias Bonfire.Data.Social.Profile
  alias Ecto.Changeset


  def changeset(profile \\ %Profile{}, params) do
    profile
    |> Profile.changeset(params)
    |> Changeset.validate_length(:name, min: 3, max: 50)
    |> Changeset.validate_length(:summary, min: 0, max: 1024)
  end

end
