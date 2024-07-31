defmodule Bonfire.Me.Mails do
  @moduledoc """
  Handles email sending functionality for accounts and users
  """

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

  @doc """
  Sends a confirmation email based on the specified action.

  ## Parameters

    - `account`: The `%Account{}` struct for the user.
    - `opts`: Options including `:confirm_action`, which determines the type of email to send.

  ## Examples

      iex> Bonfire.Me.Mails.confirm_email(%Account{})
      # sends signup confirmation

      iex> Bonfire.Me.Mails.confirm_email(%Account{}, confirm_action: :forgot_password)

      iex> Bonfire.Me.Mails.confirm_email(%Account{}, confirm_action: :forgot_password)
  """
  def confirm_email(account, opts \\ []) do
    case opts[:confirm_action] do
      :forgot_password -> forgot_password(account)
      :login -> forgot_password(account)
      _ -> signup_confirm_email(account)
    end
  end

  @doc """
  Sends a confirmation email for user signup.

  ## Parameters

    - `account`: The `%Account{}` struct for the user.

  ## Examples

      iex> Bonfire.Me.Mails.signup_confirm_email(%Account{email: %{confirm_token: "token"}})
  """
  def signup_confirm_email(%Account{} = account) do
    confirm_token = Utils.e(account, :email, :confirm_token, nil)

    if is_binary(confirm_token) do
      app_name = Utils.maybe_apply(Bonfire.Application, :name, [])
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

  @doc """
  Sends a password reset email.

  ## Parameters

    - `account`: The `%Account{}` struct for the user.

  ## Examples

      iex> Bonfire.Me.Mails.forgot_password(%Account{email: %{confirm_token: "token"}})
      :ok
  """
  def forgot_password(%Account{} = account) do
    confirm_token = Utils.e(account, :email, :confirm_token, nil)

    if is_binary(confirm_token) do
      conf =
        Config.get(__MODULE__, [])
        |> Keyword.get(:forgot_password_email, [])

      app_name = Utils.maybe_apply(Bonfire.Application, :name, [])
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
