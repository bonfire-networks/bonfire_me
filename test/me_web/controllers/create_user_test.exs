defmodule Bonfire.Me.Web.CreateUserController.Test do

  use Bonfire.Me.ConnCase

  test "form renders" do
    alice = fake_account!()
    conn = conn(account: alice)
    conn = get(conn, "/create-user")
    doc = floki_response(conn)
    view = Floki.find(doc, "#create_user")
    assert [form] = Floki.find(doc, "#create-form")
    assert [_] = Floki.find(form, "#create-form_character_username")
    assert [_] = Floki.find(form, "#create-form_profile_name")
    assert [_] = Floki.find(form, "#create-form_profile_summary")
    assert [_] = Floki.find(form, "button[type='submit']")
  end

  describe "required fields" do

    test "missing all" do
      alice = fake_account!()
      conn = conn(account: alice)
      conn = post(conn, "/create-user", %{"user" => %{}})
      doc = floki_response(conn)
      assert [view] = Floki.find(doc, "#create_user")
      assert Floki.text(view) =~ "error occurred"
      assert [form] = Floki.find(doc, "#create-form")
      assert [_] = Floki.find(form, "#create-form_character_username")
      # assert_field_error(form, "create-form_character_username", ~r/can't be blank/)
      assert [_] = Floki.find(form, "#create-form_profile_name")
      # assert_field_error(form, "create-form_profile_name", ~r/can't be blank/)
      assert [_] = Floki.find(form, "#create-form_profile_summary")
      # assert_field_error(form, "create-form_profile_summary", ~r/can't be blank/)
      assert [_] = Floki.find(form, "button[type='submit']")
    end

    test "with name" do
      alice = fake_account!()
      conn = conn(account: alice)
      conn = post(conn, "/create-user", %{"user" => %{"profile" => %{"name" => Fake.name()}}})
      doc = floki_response(conn)
      assert [view] = Floki.find(doc, "#create_user")
      assert Floki.text(view) =~ "error occurred"
      assert [form] = Floki.find(doc, "#create-form")
      assert_field_good(form, "create-form_profile_name")
      # assert_field_error(form, "create-form_character_username", ~r/can't be blank/)
      # assert_field_error(form, "create-form_profile_summary", ~r/can't be blank/)
      assert [_] = Floki.find(form, "button[type='submit']")
    end


    test "with summary" do
      alice = fake_account!()
      conn = conn(account: alice)
      conn = post(conn, "/create-user", %{"user" => %{"profile" => %{"summary" => Fake.summary()}}})
      doc = floki_response(conn)
      assert [view] = Floki.find(doc, "#create_user")
      assert Floki.text(view) =~ "error occurred"
      assert [form] = Floki.find(doc, "#create-form")
      assert_field_good(form, "create-form_profile_summary")
      # assert_field_error(form, "create-form_character_username", ~r/can't be blank/)
      # assert_field_error(form, "create-form_profile_name", ~r/can't be blank/)
      assert [_] = Floki.find(form, "button[type='submit']")
    end

    test "missing username" do
      alice = fake_account!()
      conn = conn(account: alice)
      conn = post(conn, "/create-user", %{"user" => %{"profile" => %{"summary" => Fake.summary(), "name" => Fake.name()}}})
      doc = floki_response(conn)
      assert [view] = Floki.find(doc, "#create_user")
      assert Floki.text(view) =~ "error occurred"
      assert [form] = Floki.find(doc, "#create-form")
      assert_field_good(form, "create-form_profile_summary")
      assert_field_good(form, "create-form_profile_name")
      # assert_field_error(form, "create-form_character_username", ~r/can't be blank/)
      assert [_] = Floki.find(form, "button[type='submit']")
    end

    test "missing name" do
      alice = fake_account!()
      conn = conn(account: alice)
      conn = post(conn, "/create-user", %{"user" => %{"profile" => %{"summary" => Fake.summary()}, "character" => %{"username" => Fake.username()}}})
      doc = floki_response(conn)
      assert [view] = Floki.find(doc, "#create_user")
      assert Floki.text(view) =~ "error occurred"
      assert [form] = Floki.find(doc, "#create-form")
      assert_field_good(form, "create-form_profile_summary")
      assert_field_good(form, "create-form_character_username")
      # assert_field_error(form, "create-form_profile_name", ~r/can't be blank/)
      assert [_] = Floki.find(form, "button[type='submit']")
    end


  end

  test "username taken" do
    alice = fake_account!()
    user = fake_user!(alice)
    conn = conn(account: alice)
    params = %{"user" => %{"profile" => %{"summary" => Fake.summary(), "name" => Fake.name()}, "character" => %{"username" => user.character.username}}}
    conn = post(conn, "/create-user", params)
    doc = floki_response(conn)
    assert [view] = Floki.find(doc, "#create_user")
    assert Floki.text(view) =~ "already been taken"
    assert [form] = Floki.find(doc, "#create-form")
    assert_field_good(form, "create-form_profile_summary")
    assert_field_good(form, "create-form_profile_name")
    # assert_field_error(form, "create-form_character_username", ~r/has already been taken/)
    assert [_] = Floki.find(form, "button[type='submit']")
  end

  test "successfully create first user" do
    alice = fake_account!()
    conn = conn(account: alice)
    username = Fake.username()
    params = %{"user" => %{"profile" => %{"summary" => Fake.summary(), "name" => Fake.name()}, "character" => %{"username" => username}}}
    conn = post(conn, "/create-user", params)
    assert redirected_to(conn) == "/home"
    conn = get(recycle(conn), "/home")
    doc = floki_response(conn)
    assert [ok] = find_flash(doc)
    assert_flash(ok, :info, ~r/nice/)
  end

end
