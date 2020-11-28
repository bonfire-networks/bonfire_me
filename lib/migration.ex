defmodule Bonfire.Me.Migration do
  use Ecto.Migration
  import Pointers.Migration
  import Bonfire.Me.AccessControl.Migration
  import Bonfire.Me.Identity.Migration
  import Bonfire.Me.Social.Migration
  import CommonsPub.Actors.Actor.Migration
  import CommonsPub.Characters.Character.Migration
  import CommonsPub.Profiles.Profile.Migration
  import CommonsPub.Users.User.Migration

  def up do
    migrate_me_identity()
    migrate_me_access_control()
    migrate_me_social()
    migrate_actor()
  end

  def down do
    migrate_actor()
    migrate_me_identity()
    migrate_me_access_control()
    migrate_me_social()
  end


end
