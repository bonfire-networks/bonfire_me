defmodule Bonfire.Me.Web.My.SettingsUpload do
  use Bonfire.UI.Common.Web, :controller

  # params we receive:
  # %{
  #   "_csrf_token" => "yHxqH5EG6NtAe0B433A3njID",
  #   "profile" => %{
  #     "email" => "test@jfdgkjdf.space",
  #     "icon" => %Plug.Upload{
  #       content_type: "image/png",
  #       filename: "fist.png",
  #       path: "/tmp/plug-1595/multipart-1595441441-553343146418336-1"
  #     },
  #     "location" => "",
  #     "name" => "namie",
  #     "summary" => "yay"
  #   },
  # }

  def upload(%{assigns: %{current_user: current_user}} = conn, params) do
    attrs = input_to_atoms(params)

    # TODO:
    # maybe_upload(params["profile"]["icon"], "icon")
    # maybe_upload(params["profile"]["image"], "image")

    {:ok, _edit_profile} =
      Bonfire.Me.Users.update(current_user, attrs)

    conn
    |> redirect(external: "/user")
  end
end
