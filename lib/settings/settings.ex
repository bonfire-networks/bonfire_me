defmodule Bonfire.Me.Settings do
  use Bonfire.Common.Utils
  use Bonfire.Common.Repo
  # import Bonfire.Me.Integration
  alias Bonfire.Common.Extend
  alias Bonfire.Common.Config

  @doc """
  Get config value for a config key (optionally from a specific OTP app or Bonfire extension)

  These two calls have the same result (i.e. specifying a module as the first key will add the OTP app of that module as the first key):
  `get([:bonfire_me, Bonfire.Me.Users])`
  `get(Bonfire.Me.Users)`

  Same with these two (i.e. not specifying a module or app as the first key will default to the main OTP app):
  `get([:random_atom, :sub_key])`
  `get([:bonfire, :random_atom, :sub_key])`
  """
  def get(key, default \\ nil, opts \\ [])

  def get(keys, default, opts) when is_list(keys) do
    {[otp_app], keys_tree} =
      Config.keys_tree(keys)
      |> Enum.split(1)

    debug(keys_tree, "Get settings in #{inspect(otp_app)} for")

    case get_merged_ext(otp_app, opts) do
      [] ->
        default

      nil ->
        default

      result ->
        if keys_tree != [] do
          if Keyword.keyword?(result) or is_map(result) do
            get_in(result, keys_tree)
            |> debug(inspect(keys_tree))
            |> maybe_fallback(default)
          else
            error(result, "Settings are in an invalid structure and can't be used")
            default
          end
        else
          maybe_fallback(result, default)
        end
    end
  end

  def get(key, default, opts) do
    get([key], default, opts)
  end

  def get!(key, opts) do
    case get(key, nil, opts) do
      nil ->
        raise "Missing setting or configuration value: #{inspect(key, pretty: true)}"

      value ->
        value
    end
  end

  defp maybe_fallback(nil, fallback), do: fallback
  defp maybe_fallback(val, _fallback), do: val

  @doc """
  Get all config keys/values for a Bonfire extension or OTP app
  """
  def get_merged_ext(module_or_otp_app, opts \\ []) do
    otp_app =
      Extend.maybe_extension_loaded!(module_or_otp_app) ||
        Config.top_level_otp_app()

    # TODO get and merge dominoes based on current_user > current_account > instance > Config
    fetch_all_scopes(otp_app, opts)
    |> deep_merge_reduce()

    # |> debug("domino-merged settings for #{inspect(otp_app)}")
  end

  def get_merged_ext!(module_or_otp_app, opts \\ []) do
    case get_merged_ext(module_or_otp_app, opts) do
      nil ->
        raise "Missing settings or configuration for extension: #{inspect(module_or_otp_app, pretty: true)}"
        []

      value ->
        value
    end
  end

  # @doc "Fetch all config & settings, both from Mix.Config and DB. Order matters!"
  defp fetch_all_scopes(otp_app, opts) do
    # debug(opts, "opts")
    current_user = current_user(opts)
    current_account = current_account(opts)
    # debug(current_user, "current_user")
    # debug(current_account, "current_account")

    if is_nil(current_user) and is_nil(current_account) and e(opts, :scope, opts) != :instance do
      warn(
        otp_app,
        "You should pass a current_user and/or current_account in opts depending on what scope of Settings you want - for OTP app:"
      )
    end

    #  |> debug()
    ([
       Config.get_ext(otp_app)
     ] ++
       [
         maybe_fetch({:current_account, current_account}, opts)
         |> e(:data, otp_app, nil)
       ] ++
       [
         maybe_fetch({:current_user, current_user}, opts)
         #  |> debug()
         #  |> e(:data, otp_app, nil)
         |> e(:data, nil)
         #  |> debug()
         |> e(otp_app, nil)
         #  |> debug()
       ])
    # |> debug()
    |> filter_empty([])

    # |> debug("list of different configs and settings for #{inspect(otp_app)}")
  end

  # not including this line in fetch_all_scopes because load_instance_settings preloads it into Config
  # [load_instance_settings() |> e(otp_app, nil) ] # should already be loaded in Config

  def load_instance_settings() do
    maybe_fetch({:instance, instance_scope()}, preload: true)
    |> e(:data, nil)
  end

  def maybe_fetch(scope, opts \\ [])

  def maybe_fetch({_scope, scoped} = scope_tuple, opts) do
    case scoped_object(scope_tuple) do
      %{settings: %Ecto.Association.NotLoaded{}} -> maybe_fetch(scoped, opts)
      %{settings: settings} -> settings
      _ -> maybe_fetch(scoped, opts)
    end
  end

  def maybe_fetch(scope, opts) when not is_nil(scope) do
    case ulid(scope) do
      nil ->
        error(
          scope,
          "no ID for scope"
        )

        nil

      id ->
        if e(opts, :preload, nil) do
          do_fetch(id)
        else
          if Config.get(:env) != :test,
            do:
              warn(
                scope,
                "cannot lookup Settings since they aren't already preloaded in scoped object"
              )

          nil
        end
    end
  end

  def maybe_fetch(scope, _opts) do
    debug(scope, "invalid scope")
    nil
  end

  defp do_fetch(id) do
    query_filter(Bonfire.Data.Identity.Settings, %{id: id})
    # |> proload([:pointer]) # workaround for error "attempting to cast or change association `pointer` from `Bonfire.Data.Identity.Settings` that was not loaded. Please preload your associations before manipulating them through changesets"
    |> repo().maybe_one()
  end

  @doc """
  Put a setting using a key like `:key` or list of nested keys like `[:top_key, :sub_key]`
  """
  def put(keys, value, opts) when is_list(keys) do
    # keys = Config.keys_tree(keys) # Note: doing this in set/2 instead
    # |> debug("Putting settings for")
    map_put_in(keys, value)
    |> info("map_put_in")
    |> input_to_atoms(false, true)
    |> info("input_to_atoms")
    |> maybe_to_keyword_list(true)
    |> info("maybe_to_keyword_list")
    |> set(opts)
  end

  def put(key, value, opts), do: put([key], value, opts)

  def map_put_in(root \\ %{}, keys, value) do
    # root = %{} or non empty map
    # keys = [:a, :b, :c]
    # value = 3
    put_in(root, Enum.map(keys, &Access.key(&1, %{})), value)
  end

  @doc """
  Set several settings at once.
  Accepts nested attributes as map with string keys (which are transformed into keyword list), or a keyword list.
  Determines what scope to use & sets/updates settings for it.
  """
  def set(attrs, opts) when is_map(attrs) do
    attrs
    |> input_to_atoms(false, true)
    |> debug("settings to set as atoms")
    |> set_with_hooks(opts)
  end

  def set(settings, opts) when is_list(settings) do
    # FIXME: optimise (do not convert to map and then back)
    Enum.into(settings, %{})
    |> set_with_hooks(opts)
  end

  def reset_instance() do
    with {:ok, set} <- do_update(%Bonfire.Data.Identity.Settings{id: ulid!(instance_scope())}, []) do
      # also put_env to cache it in Elixir's Config
      Config.put([])

      {:ok, set}
    end
  end

  # TODO: find a better, more pluggable way to add hooks to settings
  defp set_with_hooks(
         %{Bonfire.Me.Users => %{discoverable: false}, scope: :user} = attrs,
         opts
       ) do
    current_user = current_user_required!(opts)

    do_set(attrs, opts)

    Bonfire.Boundaries.Controlleds.remove_acls(
      current_user,
      :guests_may_see_read
    )

    Bonfire.Boundaries.Controlleds.add_acls(
      current_user,
      :guests_may_read
    )
  end

  defp set_with_hooks(
         %{Bonfire.Me.Users => %{discoverable: true}, scope: :user} = attrs,
         opts
       ) do
    current_user = current_user_required!(opts)

    do_set(attrs, opts)

    Bonfire.Boundaries.Controlleds.remove_acls(
      current_user,
      :guests_may_read
    )

    Bonfire.Boundaries.Controlleds.add_acls(
      current_user,
      :guests_may_see_read
    )
  end

  defp set_with_hooks(attrs, opts) do
    do_set(attrs, opts)
  end

  defp do_set(attrs, opts) when is_map(attrs) do
    attrs
    |> maybe_to_keyword_list(true)
    |> do_set(opts)
  end

  defp do_set(settings, opts) when is_list(settings) do
    current_user = current_user(opts)
    current_account = current_account(opts)
    # FIXME: use instance boundaries (so need to associate each setting to a verb?)
    is_admin =
      e(opts, :skip_boundary_check, nil) ||
        Bonfire.Me.Users.is_admin?(current_user || current_account)

    scope =
      case maybe_to_atom(e(settings, :scope, nil) || e(opts, :scope, nil))
           |> debug("scope to set") do
        :instance when is_admin == true ->
          {:instance, instance_scope()}

        :instance ->
          raise(
            Bonfire.Fail,
            {:unauthorized,
             l("change instance settings.") <> " " <> l("Please contact an admin.")}
          )

        :account ->
          {:current_account, current_account}

        :user ->
          {:current_user, current_user}

        _ ->
          if current_user do
            {:current_user, current_user}
          else
            if current_account do
              {:current_account, current_account}
            end
          end
      end

    debug(scope, "computed scope")

    if scope do
      settings
      |> Keyword.drop([:scope])
      |> Enum.map(&Config.keys_tree/1)
      |> debug("keyword list to set for #{inspect(scope)}")
      |> set_for(scope, ..., opts)

      # TODO: if setting a key to `nil` we could remove it instead
    else
      {:error, l("You need to be authenticated to change settings.")}
    end
  end

  defp set_for({:current_user, scoped} = scope_tuple, settings, opts) do
    fetch_or_empty(scope_tuple, opts)
    # |> debug
    |> upsert(settings, ulid(scoped))
    ~> {:ok,
     %{
       assign_context: [current_user: map_put_settings(scoped, ...)]
     }}
  end

  defp set_for({:current_account, scoped} = scope_tuple, settings, opts) do
    fetch_or_empty(scope_tuple, opts)
    # |> debug
    |> upsert(settings, ulid(scoped))
    ~> {:ok,
     %{
       assign_context: [current_account: map_put_settings(scoped, ...)]
     }}
  end

  defp set_for({:instance, scoped} = scope_tuple, settings, opts) do
    with {:ok, set} <-
           fetch_or_empty(scope_tuple, opts)
           # |> debug
           |> upsert(settings, ulid(scoped)) do
      # also put_env to cache it in Elixir's Config
      Config.put(settings)

      {:ok, set}
    end
  end

  defp set_for({_, scope}, settings, opts) do
    set_for(scope, settings, opts)
  end

  defp set_for(scoped, settings, opts) do
    fetch_or_empty(scoped, opts)
    |> upsert(settings, ulid!(scoped))
  end

  defp map_put_settings(object, {:ok, settings}),
    do: map_put_settings(object, settings)

  defp map_put_settings(object, settings),
    do: Map.put(object, :settings, settings)

  defp fetch_or_empty(scoped, opts) do
    maybe_fetch(scoped, to_options(opts) ++ [preload: true]) ||
      %Bonfire.Data.Identity.Settings{}
  end

  defp upsert(
         %Bonfire.Data.Identity.Settings{data: existing_data} = settings,
         data,
         _
       )
       when is_list(existing_data) or is_map(existing_data) do
    data
    |> debug("new settings")

    existing_data
    # |> debug("existing_data")
    |> deep_merge(data)
    |> debug("merged settings to set")
    |> do_update(settings, ...)
  end

  defp upsert(
         %Bonfire.Data.Identity.Settings{id: id} = settings,
         data,
         _
       )
       when is_binary(id) do
    do_update(settings, data)
  end

  defp upsert(%{settings: _} = parent, data, _) do
    parent
    |> repo().maybe_preload(:settings)
    |> e(:settings, %Bonfire.Data.Identity.Settings{})
    |> upsert(data, ulid(parent))
  end

  defp upsert(%Bonfire.Data.Identity.Settings{} = settings, data, scope_id) do
    %{id: ulid!(scope_id), data: data}
    # |> debug()
    |> Bonfire.Data.Identity.Settings.changeset(settings, ...)
    |> info()
    |> repo().insert()
  rescue
    e in Ecto.ConstraintError ->
      warn(e, "ConstraintError - will next attempt to update instead")

      do_fetch(ulid!(scope_id))
      |> info("fetched")
      |> do_update(data)
  end

  defp do_update(
         %Bonfire.Data.Identity.Settings{} = settings,
         data
       ) do
    Bonfire.Data.Identity.Settings.changeset(settings, %{data: data})
    |> repo().update()
  end

  # def delete(key, opts \\ [])
  # def delete([key], opts), do: delete(key, opts)

  # def delete([parent_key | keys] = _keys_tree, opts) do
  #   {_, updated_parent} =
  #     get(parent_key, [])
  #     |> get_and_update_in(keys, fn _ -> :pop end)

  #   put(parent_key, updated_parent, opts)
  # end

  # def delete(key, opts) do
  #   # Config.delete(key, otp_app) # if scope==instance
  # end

  def scoped_object(scope_tuple, opts \\ [])

  def scoped_object({:current_user, scoped}, opts) do
    current_user(opts) || scoped

    # |> debug
  end

  def scoped_object({:current_account, scoped}, opts) do
    current_account(opts) || scoped

    # |> debug
  end

  def scoped_object({_, scoped}, _opts) do
    scoped
  end

  def scoped_object(scoped, _opts) do
    scoped
  end

  defp instance_scope,
    do: Bonfire.Boundaries.Circles.get_id(:local) || "3SERSFR0MY0VR10CA11NSTANCE"
end
