defmodule Bonfire.Me.Web.SettingsLive do
  use Bonfire.Web, {:surface_view, [layout: {Bonfire.UI.Social.Web.LayoutView, "without_sidebar.html"}]}
  import Where
  alias Bonfire.Web.LivePlugs

  def mount(params, session, socket) do
    LivePlugs.live_plug params, session, socket, [
      LivePlugs.LoadCurrentAccount,
      LivePlugs.LoadCurrentUser,
      LivePlugs.UserRequired,
      LivePlugs.StaticChanged,
      LivePlugs.Csrf, LivePlugs.Locale,
      &mounted/3,
    ]
  end

  defp mounted(_params, _session, socket),
    do: {:ok,
      socket
      |> assign(
        page_title: l( "Settings"),
        selected_tab: "user",
        tab_id: "",
        page: "Settings",
        trigger_submit: false,
        uploaded_files: []
      )
      |> allow_upload(:icon,
        accept: ~w(.jpg .jpeg .png .gif),
        max_file_size: 5_000_000, # make configurable, expecially once we have resizing
        max_entries: 1,
        auto_upload: true,
        progress: &handle_progress/3
      )
      |> allow_upload(:image,
        accept: ~w(.jpg .jpeg .png .gif .svg .tiff),
        max_file_size: 10_000_000, # make configurable, expecially once we have resizing
        max_entries: 1,
        auto_upload: true,
        progress: &handle_progress/3
      )
    } # |> IO.inspect

  defp handle_progress(:icon = type, entry, socket) do

    user = current_user(socket)
    scope = if e(socket, :assigns, :selected_tab, nil)=="admin", do: :instance, else: user

    if user && entry.done? do
      with %{} = uploaded_media <-
        consume_uploaded_entry(socket, entry, fn %{path: path} = meta ->
          # debug(meta, "icon consume_uploaded_entry meta")
          Bonfire.Files.IconUploader.upload(user, path)
          # |> debug("uploaded")
        end) do
          # debug(uploaded_media)
          save(type, scope, uploaded_media, socket)
      end
    else
      debug("Skip uploading because we don't know current_user")
      {:noreply, socket}
    end
  end

  defp handle_progress(:image = type, entry, socket) do
    user = current_user(socket)
    scope = if e(socket, :assigns, :selected_tab, nil)=="admin", do: :instance, else: user

    if user && entry.done? do
      with %{} = uploaded_media <-
        consume_uploaded_entry(socket, entry, fn %{path: path} = meta ->
          # debug(meta, "image consume_uploaded_entry meta")
          Bonfire.Files.ImageUploader.upload(user, path)
          # |> debug("uploaded")
        end) do
          # debug(uploaded_media)
          save(type, scope, uploaded_media, socket)
      end
    else
      debug("Skip uploading because we don't know current_user")
      {:noreply, socket}
    end
  end


  def save(:icon, :instance, uploaded_media, socket) do
    with :ok <- Bonfire.Me.Settings.put([:bonfire, :ui, :theme, :instance_icon], Bonfire.Files.IconUploader.remote_url(uploaded_media), scope: :instance, socket: socket) do
      {:noreply, socket
        |> put_flash(:info, l "Icon changed!")
        |> push_redirect(to: "/")
      }
    end
  end

  def save(:image, :instance, uploaded_media, socket) do
    with :ok <- Bonfire.Me.Settings.put([:bonfire, :ui, :theme, :instance_image], Bonfire.Files.ImageUploader.remote_url(uploaded_media), scope: :instance, socket: socket) do
      {:noreply,
      socket
        |> put_flash(:info, l "Image changed!")
        |> push_redirect(to: "/")
      }
    end
  end


  def save(:icon, %{} = user, uploaded_media, socket) do
    with {:ok, user} <- Bonfire.Me.Users.update(user, %{"profile"=> %{"icon"=> uploaded_media, "icon_id"=> uploaded_media.id}}) do
      {:noreply, socket
      |> assign(current_user: deep_merge(user, %{profile: %{icon: uploaded_media}}))
      |> put_flash(:info, l "Avatar changed!")}
    end
  end

  def save(:image, %{} = user, uploaded_media, socket) do
    with {:ok, user} <- Bonfire.Me.Users.update(user, %{"profile"=> %{"image"=> uploaded_media, "image_id"=> uploaded_media.id}}) do
      {:noreply,
      socket
      |> assign(current_user: deep_merge(user, %{profile: %{image: uploaded_media}}))
      |> put_flash(:info, l "Background image changed!")}
    end
  end



  def handle_params(%{"tab" => tab, "id" => id}, _url, socket) do
    # debug(id)
    {:noreply, assign(socket, selected_tab: tab, tab_id: id)}
  end

  # def handle_params(%{"tab" => tab, "admin_tab" => admin_tab}, _url, socket) do
  #   debug(admin_tab)
  #   {:noreply, assign(socket, selected_tab: tab, admin_tab: admin_tab)}
  # end

  def handle_params(%{"tab" => tab}, _url, socket) do
    {:noreply, assign(socket, selected_tab: tab)}
  end

  def handle_params(_, _url, socket) do
    {:noreply, socket}
  end

  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  def handle_event(action, attrs, socket), do: Bonfire.Common.LiveHandlers.handle_event(action, attrs, socket, __MODULE__)

end
