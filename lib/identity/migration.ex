defmodule Bonfire.Me.Identity.Migration do
  use Ecto.Migration
  import Pointers.Migration

  defp mmi(:up) do
    quote do
      require Bonfire.Data.Identity.Account.Migration
      require Bonfire.Data.Identity.Accounted.Migration
      require Bonfire.Data.Identity.Character.Migration
      require Bonfire.Data.Identity.Credential.Migration
      require Bonfire.Data.Identity.Email.Migration
      require Bonfire.Data.Identity.User.Migration
      Bonfire.Data.Identity.Account.Migration.migrate_account()
      Bonfire.Data.Identity.Accounted.Migration.migrate_accounted()
      Bonfire.Data.Identity.Character.Migration.migrate_character()
      Bonfire.Data.Identity.Credential.Migration.migrate_credential()
      Bonfire.Data.Identity.Email.Migration.migrate_email()
      Bonfire.Data.Identity.User.Migration.migrate_user()
    end
  end

  defp mmi(:down) do
    quote do
      require Bonfire.Data.Identity.Account.Migration
      require Bonfire.Data.Identity.Accounted.Migration
      require Bonfire.Data.Identity.Character.Migration
      require Bonfire.Data.Identity.Credential.Migration
      require Bonfire.Data.Identity.Email.Migration
      require Bonfire.Data.Identity.User.Migration
      Bonfire.Data.Identity.User.Migration.migrate_user()
      Bonfire.Data.Identity.Email.Migration.migrate_email()
      Bonfire.Data.Identity.Credential.Migration.migrate_credential()
      Bonfire.Data.Identity.Character.Migration.migrate_character()
      Bonfire.Data.Identity.Accounted.Migration.migrate_accounted()
      Bonfire.Data.Identity.Account.Migration.migrate_account()
    end
  end

  defmacro migrate_me_identity() do
    quote do
      if Ecto.Migration.direction() == :up,
        do: unquote(mmi(:up)),
        else: unquote(mmi(:down))
    end
  end
  defmacro migrate_me_identity(dir), do: mmi(dir)

end
