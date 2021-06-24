defmodule Bonfire.Me.Dashboard.Test do

  use Bonfire.Me.ConnCase
  alias Bonfire.Me.Fake

  describe "show" do

    test "not logged in" do
      conn = conn()
      conn = get(conn, "/dashboard")
      assert redirected_to(conn) =~ "/login"
    end

    test "with account" do
      account = fake_account!()
      user = fake_user!(account)
      conn = conn(account: account)
      next = "/dashboard"
      {view, doc} = floki_live(conn, next) #|> IO.inspect
      assert [_] = Floki.find(doc, "#account_dashboard")
    end

    test "with user" do
      account = fake_account!()
      user = fake_user!(account)
      conn = conn(user: user, account: account)
      next = "/dashboard"
      {view, doc} = floki_live(conn, next) #|> IO.inspect
      assert [_] = Floki.find(doc, "#user_dashboard")
    end

  end

end
