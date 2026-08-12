defmodule Bonfire.Me.Dashboard.EditProfileImagesTest.RejectingS3 do
  @moduledoc "Stands in for `ExAws` so an S3-backed upload fails the way a misconfigured bucket does (403 Forbidden), without any network access."

  def request(_op, _opts \\ []) do
    {:error,
     {:http_error, 403,
      %{
        status_code: 403,
        body:
          "<Error><Code>Forbidden</Code><Message>Forbidden</Message><Resource>/us-east-1.linodeobjects.com/data/uploads/x.png</Resource></Error>",
        headers: [{"content-type", "application/xml"}]
      }}}
  end
end

defmodule Bonfire.Me.Dashboard.EditProfileImagesTest do
  use Bonfire.UI.Me.ConnCase, async: System.get_env("TEST_UI_ASYNC") != "no"
  alias Bonfire.Me.Fake
  alias Bonfire.Me.Dashboard.EditProfileImagesTest.RejectingS3

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

    {:ok, view, _doc} = live(conn, next)

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

    {:ok, uploaded} = Floki.parse_document(render_upload(icon, "image.png"))

    [done] = Floki.attribute(uploaded, "[data-id=preview_icon]", "src")

    # |> debug
    # now has uploaded image
    assert done =~ "/data/uploads/"

    # TODO check if filesizes match?
    # File.stat!(file).size |> debug()
  end

  @tag :skip_ci
  test "an upload the storage rejects tells the user, instead of silently doing nothing" do
    # Reproduces an instance with S3 configured but the bucket/credentials rejecting the write:
    # the store fails, `Attacher.attach/3` turns it into a changeset error, and `Media.insert`
    # returns `{:error, %Ecto.Changeset{}}` — which is neither a map nor a `%Bonfire.Fail{}`, so
    # `do_handle_progress/4`'s catch-all `_ -> {:noreply, socket}` used to drop it and leave the
    # user staring at an unchanged page with the real reason only in the server log.
    Process.put([:bonfire_files, :storage], :s3)

    previous = Application.get_env(:entrepot, Entrepot.Storages.S3, [])

    # a bucket is required before the storage gets as far as issuing the request we stub out
    Application.put_env(
      :entrepot,
      Entrepot.Storages.S3,
      previous
      |> Keyword.put(:ex_aws_module, RejectingS3)
      |> Keyword.put_new(:bucket, "test-bucket")
    )

    on_exit(fn -> Application.put_env(:entrepot, Entrepot.Storages.S3, previous) end)

    account = fake_account!()
    user = fake_user!(account)
    conn = conn(user: user, account: account)

    {:ok, view, _doc} = live(conn, "/settings/user/profile")

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

    html = render_upload(icon, "image.png")

    assert html =~ "Upload failed",
           "expected the rejected upload to surface an error to the user"
  end

  @tag :skip_ci
  test "upload bg image" do
    account = fake_account!()
    user = fake_user!(account)
    conn = conn(user: user, account: account)

    next = "/settings/user/profile"
    {:ok, view, doc} = live(conn, next)
    {:ok, doc} = Floki.parse_document(doc)

    [style] = Floki.attribute(doc, "[data-id='upload_banner']", "style")
    refute style =~ "/data/uploads/"

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

    {:ok, uploaded} = Floki.parse_document(render_upload(icon, "image.png"))

    [done] = Floki.attribute(uploaded, "[data-id=upload_banner]", "style")

    # |> debug
    # now has uploaded image
    assert done =~ "/data/uploads/"
  end
end
