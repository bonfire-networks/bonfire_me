defmodule Bonfire.Me.MailsTest do
  use ExUnit.Case, async: true
  use Bonfire.Common.Config

  alias Bonfire.Data.Identity.Account
  alias Bonfire.Me.Mails

  @account %Account{email: %{confirm_token: "tok-#{System.unique_integer([:positive])}"}}

  for fun <- [:login_link, :forgot_password, :signup_confirm_email] do
    test "#{fun}/1 renders both bodies and a subject" do
      email = apply(Mails, unquote(fun), [@account])

      assert is_binary(email.subject) and email.subject != ""
      assert email.html_body =~ "<!doctype html"
      assert email.html_body =~ "tok-"
      assert email.text_body =~ "tok-"
    end

    test "#{fun}/1 inlines the configured email_theme palette" do
      email = apply(Mails, unquote(fun), [@account])
      theme = Config.get([:ui, :auth, :email_theme], [])
      primary = theme[:primary] || "#e63946"
      body_bg = theme[:body_bg] || "#fff7f7"

      assert email.html_body =~ primary
      assert email.html_body =~ body_bg
    end
  end
end
