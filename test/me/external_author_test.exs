defmodule Bonfire.Me.ExternalAuthorTest do
  @moduledoc """
  An author from another site (a WordPress or Ghost author, by email) gets a user here, so what they wrote can be imported as theirs: the user of their account if they already have one, otherwise a new account they can claim later, made without sending them anything.
  """
  use Bonfire.Me.DataCase, async: false
  import Swoosh.TestAssertions

  alias Bonfire.Me.Accounts
  alias Bonfire.Me.Users
  alias Bonfire.Me.Fake

  defp new_email, do: "author-#{System.unique_integer([:positive])}@example.local"

  test "an author with no account here gets one, with a user named after them, and no email is sent" do
    email = new_email()
    handle = "newauthor#{System.unique_integer([:positive])}"

    assert {:ok, user} = Users.get_or_create_for_external_author(email, "New Author", [handle])

    assert %{} = account = Accounts.get_by_email(email)
    assert [%{id: id}] = Users.by_account!(account)
    assert id == user.id

    user = repo().maybe_preload(user, [:profile, :character])
    assert user.profile.name == "New Author"
    assert user.character.username == handle

    assert_no_email_sent()
  end

  test "an author whose email already has an account here gets that account's user" do
    account = Fake.fake_account!()
    user = Fake.fake_user!(account)
    email = repo().maybe_preload(account, :email).email.email_address

    assert {:ok, %{id: id}} =
             Users.get_or_create_for_external_author(email, "Whoever", ["whoever"])

    assert id == user.id
  end

  test "an author whose username is taken here gets it with a number after it" do
    taken = Fake.fake_user!() |> repo().maybe_preload(:character)
    username = taken.character.username

    assert {:ok, user} =
             Users.get_or_create_for_external_author(new_email(), "Someone Else", [username])

    user = repo().maybe_preload(user, :character)
    assert user.character.username =~ ~r/^#{Regex.escape(username)}_\d+$/
  end
end
