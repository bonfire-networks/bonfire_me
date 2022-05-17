defmodule Bonfire.Me.Mails do
  use Bamboo.Template, view: Bonfire.Me.Mails.EmailView

  alias Bonfire.Data.Identity.Account
  alias Bonfire.Me.Mails.EmailView
  import Bonfire.Me.Integration
  import Bonfire.Common.URIs
  import Where
  require Bonfire.Common.Localise.Gettext
  import Bonfire.Common.Localise.Gettext.Helpers

  def confirm_email(account, opts \\ []) do

    case opts[:confirm_action] do
     :forgot_password -> forgot_password(account)
     :login -> forgot_password(account)
      _ -> signup_confirm_email(account)
    end

  end

  def signup_confirm_email(%Account{email: %{confirm_token: confirm_token}}=account) when is_binary(confirm_token) do

    app_name = Application.get_env(:bonfire, :app_name, "Bonfire")
    url = url(Bonfire.UI.Me.ConfirmEmailController, [:show, confirm_token])

    if Bonfire.Common.Config.get(:env) != :test or System.get_env("START_SERVER", "false")=="true", do: warn("Email confirmation link: #{url}")

    conf =
      Bonfire.Common.Config.get(__MODULE__, [])
      |> Keyword.get(:confirm_email, [])

    new_email()
    |> assign(:current_account, account)
    |> assign(:confirm_url, url)
    |> assign(:app_name, app_name)
    |> subject(Keyword.get(conf, :subject, app_name <> l " - Confirm your email"))
    |> render(:confirm_email)
    # |> put_html_layout({EmailView, "confirm_email.html"})
    # |> put_text_layout({EmailView, "confirm_email.text"})
    # |> IO.inspect
  end

  def forgot_password(%Account{email: %{confirm_token: confirm_token}}=account) when is_binary(confirm_token) do
    conf =
      Bonfire.Common.Config.get(__MODULE__, [])
      |> Keyword.get(:forgot_password_email, [])

    app_name = Application.get_env(:bonfire, :app_name, "Bonfire")
    url = url(Bonfire.UI.Me.ForgotPasswordController, confirm_token)

    new_email()
    |> assign(:current_account, account)
    |> assign(:confirm_url, url)
    |> assign(:app_name, app_name)
    |> subject(Keyword.get(conf, :subject, app_name <> " - Reset your password"))
    |> render(:forgot_password)
  end

end
