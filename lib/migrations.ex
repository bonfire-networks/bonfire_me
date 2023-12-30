defmodule Bonfire.Me.Migrations do
  @moduledoc false
  use Ecto.Migration
  # import Needle.Migration

  defp mm(:up) do
    quote do
      require Bonfire.Data.Identity.Account.Migration
      require Bonfire.Data.Identity.Accounted.Migration
      require Bonfire.Data.Identity.Character.Migration
      require Bonfire.Data.Identity.Credential.Migration
      require Bonfire.Data.Identity.Email.Migration
      require Bonfire.Data.Identity.User.Migration
      require Bonfire.Data.Identity.Caretaker.Migration
      require Bonfire.Data.Identity.Self.Migration
      require Bonfire.Data.Identity.Named.Migration
      require Bonfire.Data.Identity.ExtraInfo.Migration
      require Bonfire.Data.Identity.AuthSecondFactor.Migration
      require Bonfire.Data.Identity.Alias.Migration

      Bonfire.Data.Identity.Named.Migration.migrate_named()
      Bonfire.Data.Identity.Account.Migration.migrate_account()
      Bonfire.Data.Identity.Accounted.Migration.migrate_accounted()
      Bonfire.Data.Identity.Character.Migration.migrate_character()
      Bonfire.Data.Identity.Credential.Migration.migrate_credential()
      Bonfire.Data.Identity.Email.Migration.migrate_email()
      Bonfire.Data.Identity.User.Migration.migrate_user()
      Bonfire.Data.Identity.Caretaker.Migration.migrate_caretaker()
      Bonfire.Data.Identity.Self.Migration.migrate_self()
      Bonfire.Data.Identity.AuthSecondFactor.Migration.migrate_auth_second_factor()
      Bonfire.Data.Identity.ExtraInfo.Migration.migrate_extra_info()
      Bonfire.Data.Identity.Alias.Migration.migrate_alias()
    end
  end

  defp mm(:down) do
    quote do
      require Bonfire.Data.Identity.Account.Migration
      require Bonfire.Data.Identity.Accounted.Migration
      require Bonfire.Data.Identity.Character.Migration
      require Bonfire.Data.Identity.Credential.Migration
      require Bonfire.Data.Identity.Email.Migration
      require Bonfire.Data.Identity.User.Migration
      require Bonfire.Data.Identity.Caretaker.Migration
      require Bonfire.Data.Identity.Self.Migration
      require Bonfire.Data.Identity.Named.Migration
      require Bonfire.Data.Identity.ExtraInfo.Migration
      require Bonfire.Data.Identity.AuthSecondFactor.Migration
      require Bonfire.Data.Identity.Alias.Migration

      Bonfire.Data.Identity.Alias.Migration.migrate_alias()
      Bonfire.Data.Identity.ExtraInfo.Migration.migrate_extra_info()
      Bonfire.Data.Identity.AuthSecondFactor.Migration.migrate_auth_second_factor()
      Bonfire.Data.Identity.Self.Migration.migrate_self()
      Bonfire.Data.Identity.Caretaker.Migration.migrate_caretaker()
      Bonfire.Data.Identity.User.Migration.migrate_user()
      Bonfire.Data.Identity.Email.Migration.migrate_email()
      Bonfire.Data.Identity.Credential.Migration.migrate_credential()
      Bonfire.Data.Identity.Character.Migration.migrate_character()
      Bonfire.Data.Identity.Accounted.Migration.migrate_accounted()
      Bonfire.Data.Identity.Account.Migration.migrate_account()
      Bonfire.Data.Identity.Named.Migration.migrate_named()
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
