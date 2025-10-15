defmodule Bonfire.Social.Repo.Migrations.InstanceAdminUser do
  @moduledoc false
  use Ecto.Migration

  import Needle.Migration

  def up do
    alter table("bonfire_data_access_control_instance_admin") do
      add_pointer(:user_id, :weak, Needle.Pointer)
    end
  end

  def down, do: nil
end
