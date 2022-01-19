defmodule Bonfire.Me.Web.SettingsLive do
  use Bonfire.Web, {:surface_view, [layout: {Bonfire.UI.Social.Web.LayoutView, "without_sidebar.html"}]}
  require Logger
  alias Bonfire.Web.LivePlugs

  def mount(params, session, socket) do
    LivePlugs.live_plug params, session, socket, [
      LivePlugs.LoadCurrentAccount,
      LivePlugs.LoadCurrentUser,
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
        max_file_size: 2_000_000, # make configurable, expecially once we have resizing
        max_entries: 1,
        auto_upload: true,
        progress: &handle_progress/3
      )
      |> allow_upload(:image,
        accept: ~w(.jpg .jpeg .png .gif .svg .tiff),
        max_file_size: 4_000_000, # make configurable, expecially once we have resizing
        max_entries: 1,
        auto_upload: true,
        progress: &handle_progress/3
      )
    } # |> IO.inspect

  defp handle_progress(:icon, entry, socket) do

    user = current_user(socket)

    if user && entry.done? do
      with {:ok, uploaded_media} <-
        consume_uploaded_entry(socket, entry, fn %{path: path} = meta ->
          # IO.inspect(meta)
          Bonfire.Files.IconUploader.upload(user, path)
        end),
        Bonfire.Me.Users.update(user, %{"profile"=> %{"icon"=> uploaded_media, "icon_id"=> uploaded_media.id}}) do
          # IO.inspect(uploaded_media)
          {:noreply, socket
          |> assign(current_user: deep_merge(user, %{profile: %{icon: uploaded_media}}))
          |> put_flash(:info, l "Avatar changed!")}
        end

    else
      Logger.info("Skip uploading because we don't know current_user")
      {:noreply, socket}
    end
  end

  defp handle_progress(:image, entry, socket) do
    user = current_user(socket)

    if user && entry.done? do
      with {:ok, uploaded_media} <-
        consume_uploaded_entry(socket, entry, fn %{path: path} = meta ->
          # IO.inspect(meta)
          Bonfire.Files.ImageUploader.upload(user, path)
        end),
        Bonfire.Me.Users.update(user, %{"profile"=> %{"image"=> uploaded_media, "image_id"=> uploaded_media.id}}) do
          # IO.inspect(uploaded_media)
          {:noreply,
          socket
          |> assign(current_user: deep_merge(user, %{profile: %{image: uploaded_media}}))
          |> put_flash(:info, l "Background image changed!")}
        end

    else
      Logger.info("Skip uploading because we don't know current_user")
      {:noreply, socket}
    end
  end

  def handle_params(%{"tab" => tab, "id" => id}, _url, socket) do
    # IO.inspect(id)
    {:noreply, assign(socket, selected_tab: tab, tab_id: id)}
  end

  # def handle_params(%{"tab" => tab, "admin_tab" => admin_tab}, _url, socket) do
  #   IO.inspect(admin_tab)
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
