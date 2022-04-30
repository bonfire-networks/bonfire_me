defmodule Bonfire.Me.Profiles do

  alias Bonfire.Data.Social.Profile
  alias Ecto.Changeset

  def context_module, do: Profile

  def changeset(profile \\ %Profile{}, params) do
    profile
    |> Profile.changeset(params)
    |> Changeset.validate_length(:name,
      min: Bonfire.Common.Config.get_ext(:bonfire_me, :validate_name_min, 3),
      max: Bonfire.Common.Config.get_ext(:bonfire_me, :validate_name_max, 50)
    )
    |> Changeset.validate_length(:summary, min: 0, max: Bonfire.Common.Config.get_ext(:bonfire_me, :validate_summary_max, 1024))
    |> EctoSparkles.SanitiseStrings.clean_html()
  end

  def indexing_object_format(%{profile: obj}), do: indexing_object_format(obj)
  def indexing_object_format(%Profile{id: _} = obj) do

    obj = Bonfire.Repo.maybe_preload(obj, [:icon, :image])

    icon = Bonfire.Files.IconUploader.remote_url(obj.icon)
    image = Bonfire.Files.ImageUploader.remote_url(obj.image)

    %{

      "index_type" => "Bonfire.Data.Social.Profile",
      "name" => obj.name,
      "summary" => obj.summary,
      "icon" => %{"url"=> icon},
      "image" => %{"url"=> image},
   }
  end

  def indexing_object_format(_), do: nil

end
