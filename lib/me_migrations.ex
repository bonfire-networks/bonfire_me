defmodule Bonfire.Me.Migrations do
  use Ecto.Migration
 import Pointers.Migration
  import CommonsPub.Accounts.Account.Migration
  import CommonsPub.Accounts.Accounted.Migration
  import CommonsPub.Access.Access.Migration
  import CommonsPub.Access.AccessGrant.Migration
  import CommonsPub.Actors.Actor.Migration
  import CommonsPub.Characters.Character.Migration
  import CommonsPub.Emails.Email.Migration
  import CommonsPub.LocalAuth.LoginCredential.Migration
  import CommonsPub.Profiles.Profile.Migration
  import CommonsPub.Users.User.Migration
  alias CommonsPub.Access.Access

  def up do

    migrate_account()
    migrate_accounted()
    migrate_email()
    migrate_login_credential()

    migrate_user()
    migrate_character()
    migrate_profile()
    migrate_actor()
  end

  def down do
    migrate_actor()
    migrate_profile()
    migrate_character()

    migrate_user()
    migrate_login_credential()
    migrate_email()
    migrate_accounted()
    migrate_account()

  end


end
