defmodule Bonfire.Me.Mails do
  use Bamboo.Template, view: Bonfire.Me.Mails.EmailView

  alias Bonfire.Data.Identity.Account
  # alias Bonfire.Me.Mails.EmailView
  alias Bonfire.Common.Utils
  # import Bonfire.Me.Integration
  import Bonfire.Common.URIs
  import Untangle
  require Bonfire.Common.Localise.Gettext
  import Bonfire.Common.Localise.Gettext.Helpers
  alias Bonfire.Common.Config

  def confirm_email(account, opts \\ []) do
    case opts[:confirm_action] do
      :forgot_password -> forgot_password(account)
      :login -> forgot_password(account)
      _ -> signup_confirm_email(account)
    end
  end

  def signup_confirm_email(%Account{} = account) do
    confirm_token = Utils.e(account, :email, :confirm_token, nil)

    if is_binary(confirm_token) do
      app_name = Bonfire.Application.name()
      url = url_path(Bonfire.UI.Me.ConfirmEmailController, [:show, confirm_token])

      if Config.env() != :test or
           System.get_env("PHX_SERVER") == "yes",
         do: warn("Email confirmation link: #{url}")

      conf =
        Config.get(__MODULE__, [])
        |> Keyword.get(:confirm_email, [])

      new_email()
      |> assign(:current_account, account)
      |> assign(:confirm_url, url)
      |> assign(:app_name, app_name)
      |> subject(Keyword.get(conf, :subject, "#{app_name} - " <> l("Confirm your email")))
      |> render(:confirm_email)

      # |> put_html_layout({EmailView, "confirm_email.html"})
      # |> put_text_layout({EmailView, "confirm_email.text"})
      # |> IO.inspect
    else
      error("No confirmation token")
    end
  end

  def forgot_password(%Account{} = account) do
    confirm_token = Utils.e(account, :email, :confirm_token, nil)

    if is_binary(confirm_token) do
      conf =
        Config.get(__MODULE__, [])
        |> Keyword.get(:forgot_password_email, [])

      app_name = Bonfire.Application.name()
      url = url_path(Bonfire.UI.Me.ForgotPasswordController, confirm_token)

      new_email()
      |> assign(:current_account, account)
      |> assign(:confirm_url, url)
      |> assign(:app_name, app_name)
      |> subject(Keyword.get(conf, :subject, "#{app_name} - #{l("Reset your password")}"))
      |> render(:forgot_password)
    else
      error(l("No confirmation token"))
    end
  end
end
