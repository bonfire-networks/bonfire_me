defmodule Bonfire.Me.Migration do

  @create_add_perms """
  create or replace function add_perms(bool, bool)
  returns bool as $$
  begin
    if $1 is null then return $2; end if;
    if $2 is null then return $1; end if;
    return ($1 and $2);
  end;
  $$ language plpgsql
  """
  @create_agg_perms """
  create aggregate agg_perms(bool) (
    sfunc = add_perms,
    stype = bool,
    combinefunc = add_perms,
    parallel = safe
  )
  """
  @drop_add_perms "drop function add_perms(bool, bool)"
  @drop_agg_perms "drop aggregate agg_perms(bool)"

  def migrate_functions do
    # this has the appearance of being muddled, but it's not
    Ecto.Migration.execute(@create_add_perms, @drop_agg_perms)
    Ecto.Migration.execute(@create_agg_perms, @drop_add_perms)
  end

  defp mm(:up) do
    quote do
      require Bonfire.Me.AccessControl.Migration
      require Bonfire.Me.ActivityPub.Migration
      require Bonfire.Me.Identity.Migration
      require Bonfire.Me.Social.Migration
      Bonfire.Me.AccessControl.Migration.migrate_me_access_control()
      Bonfire.Me.ActivityPub.Migration.migrate_me_activity_pub()
      Bonfire.Me.Identity.Migration.migrate_me_identity()
      Bonfire.Me.Social.Migration.migrate_me_social()
      Bonfire.Me.Migration.migrate_functions()
      Ecto.Migration.flush()
      Bonfire.Me.Fixtures.insert()
    end
  end

  defp mm(:down) do
    quote do
      require Bonfire.Me.AccessControl.Migration
      require Bonfire.Me.ActivityPub.Migration
      require Bonfire.Me.Identity.Migration
      require Bonfire.Me.Social.Migration
      Bonfire.Me.Migration.migrate_functions()
      Bonfire.Me.Social.Migration.migrate_me_social()
      Bonfire.Me.Identity.Migration.migrate_me_identity()
      Bonfire.Me.ActivityPub.Migration.migrate_me_activity_pub()
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
