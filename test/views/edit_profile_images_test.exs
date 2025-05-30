defmodule Bonfire.Me.Dashboard.EditProfileImagesTest do
  use Bonfire.UI.Me.ConnCase, async: true
  alias Bonfire.Me.Fake

  @tag :skip_ci
  test "upload avatar" do
    account = fake_account!()
    user = fake_user!(account)
    conn = conn(user: user, account: account)

    next = "/settings/user/profile"
    # |> IO.inspect
    # {view, doc} = floki_live(conn, next)

    # [src] = Floki.attribute(doc, "[data-id='preview_icon']", "src")
    # has placeholder avatar
    # assert src =~ "/images/avatar.png"

    {:ok, view, doc} = live(conn, next)

    # //////////////////

    file = Path.expand("../fixtures/icon.png", __DIR__)

    icon =
      file_input(view, "[data-id=upload_icon]", :icon, [
        %{
          last_modified: 1_594_171_879_000,
          name: "image.png",
          content: File.read!(file),
          type: "image/png"
        }
      ])

    uploaded = render_upload(icon, "image.png")

    # Floki.find(uploaded, "[data-id=upload_icon]")
    # |> debug("dsdssddsds")

    [done] = Floki.attribute(uploaded, "[data-id=preview_icon]", "src")

    # |> debug
    # now has uploaded image
    assert done =~ "/data/uploads/"

    # TODO check if filesizes match?
    # File.stat!(file).size |> debug()
  end

  @tag :skip_ci
  test "upload bg image" do
    account = fake_account!()
    user = fake_user!(account)
    conn = conn(user: user, account: account)

    next = "/settings/user/profile"
    {:ok, view, doc} = live(conn, next)
    # |> IO.inspect
    # {view, doc} = floki_live(conn, next)
    # open_browser(view)
    [style] = Floki.attribute(doc, "[data-id='upload_banner']", "style")
    refute style =~ "background-image: url('/data/uploads/"

    file = Path.expand("../fixtures/icon.png", __DIR__)

    icon =
      file_input(view, "[data-scope=upload_banner_form]", :banner, [
        %{
          last_modified: 1_594_171_879_000,
          name: "image.png",
          content: File.read!(file),
          type: "image/png"
        }
      ])

    uploaded = render_upload(icon, "image.png")

    [done] = Floki.attribute(uploaded, "[data-id=upload_banner]", "style")

    # |> debug
    # now has uploaded image
    assert done =~ "background-image: url('/data/uploads/"
  end
end
