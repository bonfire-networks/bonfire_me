defmodule Bonfire.Me.Migration do
  use Ecto.Migration

  defp mm(:up) do
    quote do
      require Bonfire.Data.ActivityPub.Actor.Migration
      require Bonfire.Me.AccessControl.Migration
      require Bonfire.Me.Identity.Migration
      require Bonfire.Me.Social.Migration
      Bonfire.Me.AccessControl.Migration.migrate_me_access_control()
      Bonfire.Me.Identity.Migration.migrate_me_identity()
      Bonfire.Me.Social.Migration.migrate_me_social()
      Bonfire.Data.ActivityPub.Actor.Migration.migrate_actor()
      Ecto.Migration.flush()
      Bonfire.Me.Fixtures.insert()
    end
  end

  defp mm(:down) do
    quote do
      require Bonfire.Data.ActivityPub.Actor.Migration
      require Bonfire.Me.AccessControl.Migration
      require Bonfire.Me.Identity.Migration
      require Bonfire.Me.Social.Migration
      Bonfire.Data.ActivityPub.Actor.Migration.migrate_actor()
      Bonfire.Me.Social.Migration.migrate_me_social()
      Bonfire.Me.Identity.Migration.migrate_me_identity()
      Bonfire.Me.AccessControl.Migration.migrate_me_access_control()
    end
  end

  defmacro migrate_me() do
    quote do
      if Ecto.Migration.direction() == :up,
        do: unquote(mm(:up)),
        else: unquote(mm(:down))
    end
  end
  defmacro migrate_me(dir), do: mm(dir)

end
