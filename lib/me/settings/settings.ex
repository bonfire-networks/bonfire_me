defmodule Bonfire.Me.Settings do
  use Bonfire.Common.Utils
  import Bonfire.Me.Integration

  def set(attrs, opts) do
    current_user = current_user(opts)
    current_account = current_account(opts)
    is_admin = Bonfire.Me.Users.is_admin?(current_user || current_account)

    scope = case e(attrs, "scope", nil) do
      "instance" when is_admin==true -> {:instance, nil} # TODO, needs a static ULID
      "account" -> {:current_account, ulid(current_account)}
      "user" -> {:current_user, ulid(current_user)}
      _ ->
        if current_user, do: {:current_user, ulid(current_user)}, else: {:current_account, ulid(current_account)}
    end
    |> debug

    attrs = attrs
    |> debug
    |> Map.drop(["scope"])
    |> input_to_atoms(false, true)
    |> maybe_to_keyword_list()
    |> dump()
    |> set(scope, ..., opts)
  end

  def set({:current_user, _scope_id}, settings, opts) do
    current_user(opts)
    |> debug
    |> upsert(settings)
  end

  def set({_, scope_id}, settings, opts) do
    set(scope_id, settings, opts)
  end

  def set(scope_id, settings, opts) do
    settings
    |> dump()
  end

  defp upsert(%{settings: _}=parent, data) do
    parent
    |> repo().maybe_preload(:settings)
    |> e(:settings, %Bonfire.Data.Identity.Settings{})
    |> upsert(data, ulid(parent))
  end

  defp upsert(%Bonfire.Data.Identity.Settings{data: existing_data}=settings, data, _) when is_list(existing_data) do
    settings
    |> Bonfire.Data.Identity.Settings.changeset(%{data: deep_merge(existing_data, data)})
    |> repo().update()
  end

  defp upsert(%Bonfire.Data.Identity.Settings{}=settings, data, scope_id) do
    settings
    |> Bonfire.Data.Identity.Settings.changeset(%{id: scope_id, data: data})
    |> repo().insert()
  end


end
