defmodule Bonfire.Me.Dashboard.Test do
  use Bonfire.Me.ConnCase
  alias Bonfire.Me.Fake

  test "upload avatar" do
    account = fake_account!()
    user = fake_user!(account)
    conn = conn(user: user, account: account)

    next = "/settings/user"
    {view, doc} = floki_live(conn, next) #|> IO.inspect

    [style] = Floki.attribute(doc, "[data-id='preview_icon']", "style")
    assert style =~ "background-image: url('http" # has placeholder

    file = Path.expand("../../fixtures/icon.png", __DIR__)

    icon = file_input(view, "[data-id='upload_icon']", :icon, [%{
      last_modified: 1_594_171_879_000,
      name: "icon.png",
      content: File.read!(file),
      type: "image/png"
    }])

    uploaded = render_upload(icon, "icon.png")

    [done] = uploaded
    |> Floki.attribute("[data-id='preview_icon']", "style")
    # |> debug
    assert done =~ "background-image: url('/data/uploads/" # now has uploaded image

    # TODO check if filesizes match?
    # File.stat!(file).size |> debug()
  end

  test "upload bg image" do
    account = fake_account!()
    user = fake_user!(account)
    conn = conn(user: user, account: account)

    next = "/settings/user"
    {view, doc} = floki_live(conn, next) #|> IO.inspect

    [style] = Floki.attribute(doc, "[data-id='upload_image']", "style")
    assert style =~ "background-image: url('http" # has placeholder

    file = Path.expand("../../fixtures/icon.png", __DIR__)

    icon = file_input(view, "[data-id='upload_image']", :image, [%{
      last_modified: 1_594_171_879_000,
      name: "image.png",
      content: File.read!(file),
      type: "image/png"
    }])

    uploaded = render_upload(icon, "image.png")

    [done] = uploaded
    |> Floki.attribute("[data-id='upload_image']", "style")
    # |> debug
    assert done =~ "background-image: url('/data/uploads/" # now has uploaded image

  end

end
