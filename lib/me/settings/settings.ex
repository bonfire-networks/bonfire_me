defmodule Bonfire.Me.Settings do
  use Bonfire.Common.Utils
  use Bonfire.Repo
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
    {[otp_app], keys_tree} = keys_tree(keys) |> Enum.split(1)

    debug(keys_tree, "Get settings in #{inspect otp_app} for")
    case get_all_ext(otp_app, opts)
         |> get_in(keys_tree) do
      nil ->
        # Config.get_ext(otp_app, keys, default)
        nil

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
    |> debug("list of config and settings for #{inspect otp_app}")
    |> deep_merge_reduce()
    |> debug("domino-merged settings")
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

  def fetch({_, scoped} = scope_tuple) do
    case scoped_object(scope_tuple) do
      %{settings: %Ecto.Association.NotLoaded{}} -> fetch(scoped)
      %{settings: settings} -> settings
      nil -> fetch(scoped)
    end
  end

  def fetch(scope) when not is_nil(scope) do
    debug("fallback to querying if Settings aren't already loaded in opts data")
    query_filter(Bonfire.Data.Identity.Settings, %{id: ulid(scope)})
    |> repo().one()
  end
  def fetch(_), do: nil

  @doc """
  Fetch all config & settings, both from Mix.Config and DB. Order matters!
  """
  def fetch_all_scopes(otp_app, opts) do
    (
      [Config.get_ext(otp_app)]
      ++
      # [fetch({:instance, "TODO_INSTANCE"}, opts))]
      # ++
      [fetch({:current_account, current_account(opts)}) |> e(:data, otp_app, nil)]
      ++
      [fetch({:current_user, current_user(opts)})|> e(:data, otp_app, nil)]
    )
    |> filter_empty([])
  end

  @doc """
  Determine what scope to use & set settings for it.
  Accepts nested attributes as map with string keys (which are transformed into keyword list)
  """
  def set(attrs, opts) do
    current_user = current_user(opts)
    current_account = current_account(opts)
    is_admin = Bonfire.Me.Users.is_admin?(current_user || current_account)

    scope = case maybe_to_atom(e(attrs, "scope", nil)) || e(opts, :scope, nil) do
      :instance when is_admin==true -> {:instance, nil} # TODO, needs a static ULID
      :account -> {:current_account, ulid(current_account)}
      :user -> {:current_user, ulid(current_user)}
      _ ->
        if current_user do
          {:current_user, ulid(current_user)}
        else
          if current_account do
            {:current_account, ulid(current_account)}
          else
            {:instance, nil} # TODO
          end
        end
    end
    |> debug

    attrs = attrs
    |> debug("attrs")
    |> Map.drop(["scope"])
    |> input_to_atoms(false, true)
    |> maybe_to_keyword_list()
    |> debug("keyword list to set")
    |> set(scope, ..., opts)
  end

  @doc """
  Set settings for a specific module or app like `:bonfire_me` or `Bonfire.Me.Users`
  Specify which settings with a key like `:key` or list of nested keys like `[:top_key, :sub_key]`
  """
  def put_ext(module_or_otp_app, key_or_keys_tree, value, opts \\ [])
  def put_ext(module_or_otp_app, key, value, opts) when not is_list(key), do: put_ext(module_or_otp_app, [key], value, opts)
  def put_ext(module_or_otp_app, keys_tree, value, opts), do: put([module_or_otp_app] ++ keys_tree, value, opts)

  @doc """
  Set settings using a key like `:key` or list of nested keys like `[:top_key, :sub_key]`
  """
  def put(key, value, opts \\ [])
  def put(keys, value, opts) when is_list(keys) do
    keys_tree = keys_tree(keys)
    |> debug("Putting settings for")

    parent =
      []
      |> put_in(keys_tree, value)
      |> dump("Set with attrs")
      |> set(opts)

    # Config.put(keys_tree, value, otp_app) # if scope==instance
  end
  def put(key, value, opts), do: set([key], value, opts)


  def set({:current_user, _scoped} = scope_tuple, settings, opts) do
    scoped_object(scope_tuple, opts)
    # |> debug
    |> upsert(settings)
    # TODO: put in cache & assigns
  end

  def set({:current_account, _scoped} = scope_tuple, settings, opts) do
    scoped_object(scope_tuple, opts)
    # |> debug
    |> upsert(settings)
    # TODO: put in cache & assigns
  end

  def set({:instance, _scoped} = scope_tuple, settings, opts) do
    scoped_object(scope_tuple, opts)
    # |> debug
    |> upsert(settings)
    # TODO: put in put_env config
  end

  def set({_, scope}, settings, opts) do
    set(scope, settings, opts)
  end

  def set(scoped, settings, opts) do
    (
      fetch(scoped)
      || %Bonfire.Data.Identity.Settings{}
    )
    |> upsert(settings, ulid(scoped))
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


  @doc """
  Constructs a key path for settings/config, which always starts with an app or extension name (which defaults to the main OTP app)

  iex> Bonfire.Me.Settings.keys_tree([:bonfire_me, Bonfire.Me.Users])
    [:bonfire_me, Bonfire.Me.Users]

  iex> Bonfire.Me.Settings.keys_tree(Bonfire.Me.Users)
    [:bonfire_me, Bonfire.Me.Users]

  iex> Bonfire.Me.Settings.keys_tree(:bonfire_me)
    [:bonfire_me]

  iex> Bonfire.Me.Settings.keys_tree(:random_atom)
    [:bonfire, :random_atom]

  iex>Bonfire.Me.Settings.keys_tree([:random_atom, :sub_key])
    [:bonfire, :random_atom, :sub_key]
  """
  def keys_tree(keys) when is_list(keys) do
    maybe_module_or_otp_app = List.first(keys)
    otp_app = Extend.maybe_extension_loaded!(maybe_module_or_otp_app) || Config.top_level_otp_app()
    # debug(otp_app)

    if maybe_module_or_otp_app !=otp_app do
      [otp_app] ++ keys # add the module name to the key tree
    else
      keys
    end
  end
  def keys_tree(key), do: keys_tree([key])

  def scoped_object(scope_tuple, opts \\ [])

  def scoped_object({:current_user, scoped}, opts) do
    current_user(opts) || scoped
    # |> debug
  end

  def scoped_object({:current_account, scoped}, opts) do
    current_account(opts) || scoped
    # |> debug
  end

  def scoped_object({:instance, scoped}, opts) do
    scoped
    |> debug("! TODO for instance !")
  end

end
