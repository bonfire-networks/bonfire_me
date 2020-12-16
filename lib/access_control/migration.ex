defmodule Bonfire.Me.AccessControl.Migration do
  use Ecto.Migration
  import Pointers.Migration

  defp mmac(:up) do
    quote do
      require Bonfire.Data.AccessControl.Access.Migration
      require Bonfire.Data.AccessControl.Acl.Migration
      require Bonfire.Data.AccessControl.Controlled.Migration
      require Bonfire.Data.AccessControl.Grant.Migration
      require Bonfire.Data.AccessControl.InstanceAdmin.Migration
      require Bonfire.Data.AccessControl.Interact.Migration
      require Bonfire.Data.AccessControl.Verb.Migration
      Bonfire.Data.AccessControl.Access.Migration.migrate_access()
      Bonfire.Data.AccessControl.Acl.Migration.migrate_acl()
      Bonfire.Data.AccessControl.Controlled.Migration.migrate_controlled()
      Bonfire.Data.AccessControl.Grant.Migration.migrate_grant()
      Bonfire.Data.AccessControl.InstanceAdmin.Migration.migrate_instance_admin()
      Bonfire.Data.AccessControl.Verb.Migration.migrate_verb()
      Bonfire.Data.AccessControl.Interact.Migration.migrate_interact()
    end
  end

  defp mmac(:down) do
    quote do
      require Bonfire.Data.AccessControl.Access.Migration
      require Bonfire.Data.AccessControl.Acl.Migration
      require Bonfire.Data.AccessControl.Controlled.Migration
      require Bonfire.Data.AccessControl.Grant.Migration
      require Bonfire.Data.AccessControl.InstanceAdmin.Migration
      require Bonfire.Data.AccessControl.Verb.Migration
      require Bonfire.Data.AccessControl.Interact.Migration
      Bonfire.Data.AccessControl.Interact.Migration.migrate_interact()
      Bonfire.Data.AccessControl.Verb.Migration.migrate_verb()
      Bonfire.Data.AccessControl.InstanceAdmin.Migration.migrate_instance_admin()
      Bonfire.Data.AccessControl.Grant.Migration.migrate_grant()
      Bonfire.Data.AccessControl.Controlled.Migration.migrate_controlled()
      Bonfire.Data.AccessControl.Acl.Migration.migrate_acl()
      Bonfire.Data.AccessControl.Access.Migration.migrate_access()
    end
  end

  defmacro migrate_me_access_control() do
    quote do
      if Ecto.Migration.direction() == :up,
        do: unquote(mmac(:up)),
        else: unquote(mmac(:down))
    end
  end
  defmacro migrate_me_access_control(dir), do: mmac(dir)

end
