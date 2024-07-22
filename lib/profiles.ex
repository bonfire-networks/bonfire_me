defmodule Bonfire.Me.Profiles do
  @moduledoc """
  Shared helpers for profiles (such as the profile of a User or Category)

  Context for `Bonfire.Data.Social.Profile` mixin, which has these fields:
  - name
  - summary
  - website
  - location (plaintext, see )
  - icon: eg. avatar (references a `Bonfire.Files.Media`)
  - image: eg. banner
  """

  alias Bonfire.Data.Social.Profile
  alias Ecto.Changeset
  # import Untangle
  import Bonfire.Me.Integration

  @behaviour Bonfire.Common.ContextModule
  @behaviour Bonfire.Common.QueryModule
  def schema_module, do: Profile

  def changeset(profile \\ %Profile{}, params) do
    profile
    |> changeset_simple(params)
    |> Changeset.validate_length(:name,
      min: Bonfire.Common.Config.get_ext(:bonfire_me, :validate_name_min, 3),
      max: Bonfire.Common.Config.get_ext(:bonfire_me, :validate_name_max, 100)
    )
    |> Changeset.validate_length(:summary,
      min: 0,
      max: Bonfire.Common.Config.get_ext(:bonfire_me, :validate_summary_max, 10240)
    )
  end

  def changeset_simple(profile \\ %Profile{}, params) do
    profile
    |> Profile.changeset(params)
    |> EctoSparkles.SanitiseStrings.clean_html()
  end

  def indexing_object_format(%{profile: obj}), do: indexing_object_format(obj)

  def indexing_object_format(%Profile{id: _} = obj) do
    obj = repo().maybe_preload(obj, [:icon, :image])

    icon = Bonfire.Files.IconUploader.remote_url(obj.icon)
    image = Bonfire.Files.ImageUploader.remote_url(obj.image)
    # info(obj.id)

    %{
      "index_type" => "Bonfire.Data.Social.Profile",
      "name" => obj.name,
      "id" => obj.id,
      "summary" => obj.summary,
      "icon" => %{"url" => icon},
      "image" => %{"url" => image}
    }
  end

  def indexing_object_format(_), do: nil
end
