defmodule Bonfire.Me.Mails do
  use Bamboo.Template, view: Bonfire.Me.Web.EmailView

  alias Bonfire.Data.Identity.Account
  alias Bonfire.Me.Web.EmailView
  import Bonfire.Common.URIs

  def confirm_email(%Account{}=account) do

    app_name = Application.get_env(:bonfire, :app_name, "Bonfire")
    url = path(Bonfire.Me.Web.ConfirmEmailController, [:show, account.email.confirm_token])

    if Bonfire.Common.Config.get(:env) != :test, do: IO.inspect(confirm_email_url: url)

    conf =
      Bonfire.Common.Config.get_ext(:bonfire_me, __MODULE__, [])
      |> Keyword.get(:confirm_email, [])

    new_email()
    |> assign(:current_account, account)
    |> assign(:confirm_url, url)
    |> assign(:app_name, app_name)
    |> subject(Keyword.get(conf, :subject, app_name <> " - Confirm your email"))
    |> render(:confirm_email)
    # |> put_html_layout({EmailView, "confirm_email.html"})
    # |> put_text_layout({EmailView, "confirm_email.text"})
    # |> IO.inspect
  end

  def forgot_password(%Account{email: %{email_address: email}}=account) when is_binary(email) do
    conf =
      Bonfire.Common.Config.get_ext(:bonfire_me, __MODULE__, [])
      |> Keyword.get(:reset_password_email, [])

    new_email()
    |> assign(:current_account, account)
    |> subject(Keyword.get(conf, :subject, Application.get_env(:bonfire, :app_name, "Bonfire") <> " Reset your password"))
    |> render(:forgot_password)
  end

end
