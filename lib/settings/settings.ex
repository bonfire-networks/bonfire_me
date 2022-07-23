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
    {[otp_app], keys_tree} = Config.keys_tree(keys) |> Enum.split(1)

    debug(keys_tree, "Get settings in #{inspect otp_app} for")

    case get_all_ext(otp_app, opts) |> get_in(keys_tree) do
      nil ->
        # Config.get_ext(otp_app, keys, default)
        default

      any ->
        any
    end
  end
  def get(key, default, opts) do
    get([key], default, opts)
  end

  def get!(key, opts) do
    case get(key, nil, opts) do
      nil ->
        raise ("Missing setting or configuration value: #{inspect(key, pretty: true)}")
      value ->
        value
    end
  end

  @doc """
  Get all config keys/values for a Bonfire extension or OTP app
  """
  def get_all_ext(module_or_otp_app, opts \\ []) do

    if opts == [], do: warn(module_or_otp_app, "You should pass a current_user or current_account in opts to Settings.get_ext/2 if you want user or account settings for")

    otp_app = Extend.maybe_extension_loaded!(module_or_otp_app) || Config.top_level_otp_app()

    # TODO get and merge dominoes based on current_user > current_account > instance > Config
    fetch_all_scopes(otp_app, opts)
    # |> debug("list of different configs and settings for #{inspect otp_app}")
    |> deep_merge_reduce()
    # |> debug("domino-merged settings")
  end

  def get_all_ext!(module_or_otp_app, opts \\ []) do
    case get_all_ext(module_or_otp_app, opts) do
      nil ->
        raise ("Missing settings or configuration for extension: #{inspect(module_or_otp_app, pretty: true)}")
        []
      value ->
        value
    end
  end

  @doc """
  Fetch all config & settings, both from Mix.Config and DB. Order matters!
  """
  def fetch_all_scopes(otp_app, opts) do
    (
      [Config.get_ext(otp_app)]
      # ++
      # [load_instance_settings() |> e(otp_app, nil) ] # should already be loaded in Config
      ++
      [fetch({:current_account, current_account(opts)}) |> e(:data, otp_app, nil)]
      ++
      [fetch({:current_user, current_user(opts)})|> e(:data, otp_app, nil)]
    )
    |> filter_empty([])
  end

  def load_instance_settings() do
    fetch({:instance, instance_scope()})
    |> e(:data, nil)
  end

  def fetch({_, scoped} = scope_tuple) do
    case scoped_object(scope_tuple) do
      %{settings: %Ecto.Association.NotLoaded{}} -> fetch(scoped)
      %{settings: settings} -> settings
      _ -> fetch(scoped)
    end
  end

  def fetch(scope) when not is_nil(scope) do
    if is_map(scope), do: warn(scope, "fallback to querying since Settings aren't already preloaded in scoped object")
    query_filter(Bonfire.Data.Identity.Settings, %{id: ulid(scope)})
    |> repo().one()
  end
  def fetch(_), do: []

  @doc """
  Put a setting using a key like `:key` or list of nested keys like `[:top_key, :sub_key]`
  """
  def put(keys, value, opts) when is_list(keys) do
    # keys = Config.keys_tree(keys) # Note: doing this in set/2 instead
    # |> debug("Putting settings for")
    map_put_in(keys, value)
    |> maybe_to_keyword_list()
    |> set(opts)
  end
  def put(key, value, opts), do: set([key], value, opts)

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
    |> debug("input as atoms")
    |> set_with_hooks(opts)
  end
  def set(settings, opts) when is_list(settings) do
    Enum.into(settings, %{}) # FIXME: optimise (do not convert to map and then back)
    |> set_with_hooks(opts)
  end

  # TODO: find a better, more pluggable way to add hooks to settings
  defp set_with_hooks(%{Bonfire.Me.Users => %{discoverable: false}, scope: :user} = attrs, opts) do
    do_set(attrs, opts)
    Bonfire.Boundaries.Controlleds.remove_acls(current_user(opts), :guests_may_see_read)
    Bonfire.Boundaries.Controlleds.add_acls(current_user(opts), :guests_may_read)
  end
  defp set_with_hooks(%{Bonfire.Me.Users => %{discoverable: true}, scope: :user} = attrs, opts) do
    do_set(attrs, opts)
    Bonfire.Boundaries.Controlleds.remove_acls(current_user(opts), :guests_may_read)
    Bonfire.Boundaries.Controlleds.add_acls(current_user(opts), :guests_may_see_read)
  end
  defp set_with_hooks(attrs, opts) do
    do_set(attrs, opts)
  end

  def do_set(attrs, opts) when is_map(attrs) do
    attrs
    |> maybe_to_keyword_list()
    |> do_set(opts)
  end

  def do_set(settings, opts) when is_list(settings) do
    current_user = current_user(opts)
    current_account = current_account(opts)
    is_admin = Bonfire.Me.Users.is_admin?(current_user || current_account)

    scope = case maybe_to_atom(e(settings, :scope, nil)) || e(opts, :scope, nil) do
      :instance when is_admin==true -> {:instance, instance_scope()}
      :account -> {:current_account, ulid(current_account)}
      :user -> {:current_user, ulid(current_user)}
      _ ->
        if current_user do
          {:current_user, ulid(current_user)}
        else
          if current_account do
            {:current_account, ulid(current_account)}
          end
        end
    end

    if scope do
      settings
      |> Keyword.drop([:scope])
      |> Enum.map(&Config.keys_tree/1)
      |> debug("keyword list to set for #{inspect scope}")
      |> set(scope, ..., opts)

    else
      {:error, l "You need to be authenticated to change settings."}
    end
  end


  def set({:current_user, scoped} = scope_tuple, settings, opts) do
    fetch_or_empty(scope_tuple)
    # |> debug
    |> upsert(settings, ulid(scoped))
    ~> {:ok, %{assign_context: [current_user: map_put_settings(current_user(opts), ...)]}}
    # TODO: put into assigns
  end

  def set({:current_account, scoped} = scope_tuple, settings, _opts) do
    fetch_or_empty(scope_tuple)
    # |> debug
    |> upsert(settings, ulid(scoped))
    # ~> {:assign, current_account(opts)}
    # TODO: put into assigns
  end

  def set({:instance, scoped} = scope_tuple, settings, _opts) do
    with {:ok, set} <- fetch_or_empty(scope_tuple)
    # |> debug
    |> upsert(settings, ulid(scoped)) do
      # also put_env to cache it in Elixir's Config
      Config.put(settings)

      {:ok, set}
    end
  end

  def set({_, scope}, settings, opts) do
    set(scope, settings, opts)
  end

  def set(scoped, settings, _opts) do
    fetch_or_empty(scoped)
    |> upsert(settings, ulid(scoped))
  end

  defp map_put_settings(object, {:ok, settings}), do: map_put_settings(object, settings)
  defp map_put_settings(object, settings), do: object |> Map.put(:settings, settings)

  defp fetch_or_empty(scoped) do
    fetch(scoped)
    || %Bonfire.Data.Identity.Settings{}
  end

  defp upsert(parent_or_settings, data, scope_id \\ nil)

  defp upsert(%{settings: _}=parent, data, _) do
    parent
    |> repo().maybe_preload(:settings)
    |> e(:settings, %Bonfire.Data.Identity.Settings{})
    |> upsert(data, ulid(parent))
  end

  defp upsert(%Bonfire.Data.Identity.Settings{data: existing_data}=settings, data, _) when is_list(existing_data) do
    deep_merge(existing_data, data)
    |> debug("merged settings to set")
    |> Bonfire.Data.Identity.Settings.changeset(settings, %{data: ...})
    |> repo().update()
  end

  defp upsert(%Bonfire.Data.Identity.Settings{}=settings, data, scope_id) do
    settings
    |> Bonfire.Data.Identity.Settings.changeset(%{id: scope_id, data: data})
    |> repo().insert()
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

  defp instance_scope, do: Bonfire.Boundaries.Circles.get_id(:local) || "3SERSFR0MY0VR10CA11NSTANCE"

end
