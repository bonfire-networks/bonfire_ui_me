defmodule Bonfire.Me.Dashboard.EditProfileImagesTest do
  use Bonfire.UI.Me.ConnCase, async: true
  alias Bonfire.Me.Fake

  test "upload avatar" do
    account = fake_account!()
    user = fake_user!(account)
    conn = conn(user: user, account: account)

    next = "/settings/profile"
    # |> IO.inspect
    {view, doc} = floki_live(conn, next)

    # [src] = Floki.attribute(doc, "[data-id='preview_icon']", "src")
    # has placeholder avatar
    # assert src =~ "/images/avatar.png"

    file = Path.expand("../fixtures/icon.png", __DIR__)

    icon =
      file_input(view, "[data-id='upload_icon']", :icon, [
        %{
          last_modified: 1_594_171_879_000,
          name: "icon.png",
          content: File.read!(file),
          type: "image/png"
        }
      ])

    uploaded = render_upload(icon, "icon.png")

    [done] = Floki.attribute(uploaded, "[data-id='preview_icon']", "src")

    # |> debug
    # now has uploaded image
    assert done =~ "/data/uploads/"

    # TODO check if filesizes match?
    # File.stat!(file).size |> debug()
  end

  test "upload bg image" do
    account = fake_account!()
    user = fake_user!(account)
    conn = conn(user: user, account: account)

    next = "/settings/profile"
    # |> IO.inspect
    {view, doc} = floki_live(conn, next)

    [style] = Floki.attribute(doc, "[data-id='upload_banner']", "style")
    refute style =~ "background-image: url('/data/uploads/"

    file = Path.expand("../fixtures/icon.png", __DIR__)

    icon =
      file_input(view, "[data-id='upload_banner']", :image, [
        %{
          last_modified: 1_594_171_879_000,
          name: "image.png",
          content: File.read!(file),
          type: "image/png"
        }
      ])

    uploaded = render_upload(icon, "image.png")

    [done] = Floki.attribute(uploaded, "[data-id='upload_banner']", "style")

    # |> debug
    # now has uploaded image
    assert done =~ "background-image: url('/data/uploads/"
  end
end
