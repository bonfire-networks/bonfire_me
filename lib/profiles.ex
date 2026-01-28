defmodule Bonfire.Me.Profiles do
  @moduledoc """
  Shared helpers for profiles (such as the profile of a User or Category)

  Context for `Bonfire.Data.Social.Profile` mixin, which has these fields:
  - name
  - summary
  - website
  - location (plaintext, see also Geolocation integration for storing GPS coordinates)
  - icon: eg. avatar (references a `Bonfire.Files.Media`)
  - image: eg. banner
  """

  use Bonfire.Common.E
  use Bonfire.Common.Config
  import Untangle
  alias Bonfire.Common.Types
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
    |> EctoSparkles.SanitiseStrings.strip_all_tags(decode_entities: true, except: [:summary])
    |> EctoSparkles.SanitiseStrings.clean_html(except: [:name, :website, :location])
  end

  def spam_check!(text, context) do
    if spam?(text, context) do
      raise Bonfire.Fail, :spam
    end
  end

  def spam?(text, context) do
    :spam == Bonfire.Common.AntiSpam.service().check_profile(text, context)
  end

  def set_profile_image(:icon, %{} = user, uploaded_media) do
    Bonfire.Me.Users.update(user, %{
      "profile" => %{
        "icon" => uploaded_media,
        "icon_id" => uploaded_media.id
      }
    })
  end

  def set_profile_image(:banner, %{} = user, uploaded_media) do
    Bonfire.Me.Users.update(user, %{
      "profile" => %{
        "image" => uploaded_media,
        "image_id" => uploaded_media.id
      }
    })
  end

  def indexing_object_format(%{profile: obj}), do: indexing_object_format(obj)

  def indexing_object_format(%{summary: _} = obj) do
    obj = repo().maybe_preload(obj, [:icon, :image])

    icon = Bonfire.Files.IconUploader.remote_url(e(obj, :icon, nil))
    image = Bonfire.Files.ImageUploader.remote_url(e(obj, :image, nil))

    %{
      # "index_type" => Types.module_to_str(Profile), # no need as can be inferred later by `Enums.maybe_to_structs/1`
      # "id" => id(obj),
      "name" => e(obj, :name, nil),
      "summary" => e(obj, :summary, nil),
      "website" => e(obj, :website, nil),
      "location" => e(obj, :location, nil)
      # NOTE: do not store images in index, instead rely on preloading from DB when displaying results
      # "icon" => %{"url" => icon}, # TODO: index alt tags
      # "image" => %{"url" => image}
    }
  end

  def indexing_object_format(_), do: nil

  @doc """
  Temporary function:
  Fixes HTML entities in a profile name by username.

  Re-processes the profile through the changeset to decode any HTML entities.

  ## Examples

      > Bonfire.Me.Profiles.fix_profile_name("username")
      {:ok, %User{}}
  """
  def fix_profile_name(username) when is_binary(username) do
    with {:ok, user} <- Bonfire.Me.Users.by_username(username) do
      user = repo().preload(user, [:profile])
      name = e(user, :profile, :name, nil)

      if name && String.contains?(name, "&") do
        debug(name, "fixing name")

        # Decode entities first so Ecto sees it as a change
        decoded_name = HtmlEntities.decode(name)

        changeset =
          changeset_simple(user.profile, %{name: decoded_name})
          |> debug("changeset prepared for")

        case repo().update(changeset) do
          {:ok, _profile} ->
            debug(decoded_name, "updated profile name to")
            {:ok, user}

          error ->
            error
        end
      else
        debug(username, "no changes needed for user")
        {:ok, user}
      end
    end
  end
end
