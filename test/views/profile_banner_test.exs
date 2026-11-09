defmodule Bonfire.UI.Me.ProfileBannerTest do
  @moduledoc "A local user's uploaded banner shows on their profile hero, both to themselves and to other local users."
  use Bonfire.UI.Me.ConnCase, async: System.get_env("TEST_UI_ASYNC") != "no"
  @moduletag :ui

  import Bonfire.Files.Simulation

  setup do
    owner_account = fake_account!()
    owner = fake_user!(owner_account)

    {:ok, banner} = fake_upload(image_file(), Bonfire.Files.BannerUploader, owner)
    {:ok, owner} = Bonfire.Me.Profiles.set_profile_image(:banner, owner, banner)

    {:ok, owner: owner, owner_account: owner_account}
  end

  # uploads are resized with vips, which CI doesn't have
  @tag Bonfire.Common.RuntimeConfig.skip_in_ci()
  test "I see my own banner", %{owner: owner, owner_account: owner_account} do
    conn(user: owner, account: owner_account)
    |> visit("/@#{owner.character.username}")
    |> wait_async()
    |> assert_has("[data-id=hero_background][style*='background-image']")
  end

  # most profiles have an avatar as well, and the hero looks at the avatar when deciding what to draw behind it
  describe "when the profile has an avatar too" do
    setup %{owner: owner} do
      {:ok, icon} = fake_upload(image_file(), Bonfire.Files.IconUploader, owner)
      {:ok, owner} = Bonfire.Me.Profiles.set_profile_image(:icon, owner, icon)
      {:ok, owner: owner}
    end

    @tag Bonfire.Common.RuntimeConfig.skip_in_ci()
    test "another local user sees the banner", %{owner: owner} do
      viewer_account = fake_account!()
      viewer = fake_user!(viewer_account)

      conn(user: viewer, account: viewer_account)
      |> visit("/@#{owner.character.username}")
      |> wait_async()
      |> assert_has("[data-id=hero_background][style*='background-image']")
    end

    @tag Bonfire.Common.RuntimeConfig.skip_in_ci()
    test "a guest sees the banner", %{owner: owner} do
      # a guest has no LiveView socket, so the page they get is the static render, which `visit` does not give (it connects a LiveView), and there is no async load to wait for
      # conn()
      # |> visit("/@#{owner.character.username}")
      # |> wait_async()
      conn()
      |> get_conn_render("/@#{owner.character.username}")
      |> assert_has("[data-id=hero_background][style*='background-image']")
    end
  end

  @tag Bonfire.Common.RuntimeConfig.skip_in_ci()
  test "I see another local user's banner", %{owner: owner} do
    viewer_account = fake_account!()
    viewer = fake_user!(viewer_account)

    conn(user: viewer, account: viewer_account)
    |> visit("/@#{owner.character.username}")
    |> wait_async()
    |> assert_has("[data-id=hero_background][style*='background-image']")
  end
end
