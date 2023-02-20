defmodule Bonfire.Me.Repo.Migrations.ImportMe  do
  @moduledoc false
  use Ecto.Migration

  import Bonfire.Me.Migration
  # accounts & users

  def change, do: migrate_me
end
