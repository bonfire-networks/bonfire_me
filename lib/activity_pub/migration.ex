defmodule Bonfire.Me.ActivityPub.Migration do
  use Ecto.Migration
  import Pointers.Migration

  defp mmap(:up) do
    quote do
      require Bonfire.Data.ActivityPub.Actor.Migration
      require Bonfire.Data.ActivityPub.Peer.Migration
      require Bonfire.Data.ActivityPub.Peered.Migration
      Bonfire.Data.ActivityPub.Actor.Migration.migrate_actor()
      Bonfire.Data.ActivityPub.Peer.Migration.migrate_peer()
      Bonfire.Data.ActivityPub.Peered.Migration.migrate_peered()
    end
  end

  defp mmap(:down) do
    quote do
      require Bonfire.Data.ActivityPub.Actor.Migration
      require Bonfire.Data.ActivityPub.Peer.Migration
      require Bonfire.Data.ActivityPub.Peered.Migration
      Bonfire.Data.ActivityPub.Peered.Migration.migrate_peered()
      Bonfire.Data.ActivityPub.Peer.Migration.migrate_peer()
      Bonfire.Data.ActivityPub.Actor.Migration.migrate_actor()
    end
  end

  defmacro migrate_me_activity_pub() do
    quote do
      if Ecto.Migration.direction() == :up,
        do: unquote(mmap(:up)),
        else: unquote(mmap(:down))
    end
  end
  defmacro migrate_me_activity_pub(dir), do: mmap(dir)

end
