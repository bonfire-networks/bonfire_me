defmodule Bonfire.Me.Migration do
  use Ecto.Migration
  import Pointers.Migration
  import Bonfire.Data.ActivityPub.Actor.Migration
  import Bonfire.Me.AccessControl.Migration
  import Bonfire.Me.Identity.Migration
  import Bonfire.Me.Social.Migration

  defmacro migrate_me() do
    quote do
      migrate_me_identity()
      migrate_me_access_control()
      migrate_me_social()
      migrate_actor()
    end
  end

end
