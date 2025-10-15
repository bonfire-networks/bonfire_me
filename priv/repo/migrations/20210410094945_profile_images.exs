defmodule Bonfire.Me.Repo.Migrations.ProfileImages do
  @moduledoc false
  use Ecto.Migration

  import Needle.Migration

  def up do
    drop_if_exists(
      constraint("bonfire_data_social_profile", "bonfire_data_social_profile_icon_id_fkey")
    )

    drop_if_exists(
      constraint("bonfire_data_social_profile", "bonfire_data_social_profile_image_id_fkey")
    )

    alter table("bonfire_data_social_profile") do
      add_pointer_if_not_exists(:icon_id, :strong, Bonfire.Files.Media)
      add_pointer_if_not_exists(:image_id, :strong, Bonfire.Files.Media)
    end
  end

  def down, do: nil
end
