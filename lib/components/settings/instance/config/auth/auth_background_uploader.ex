defmodule Bonfire.UI.Me.AuthBackgroundUploader do
  @moduledoc "Uploader for auth page background images. Stores without resizing to preserve full resolution."

  use Bonfire.Files.Definition

  @versions [:default]

  def transform(:default, _), do: :noaction

  def prefix_dir, do: "banners"

  @impl true
  def allowed_media_types do
    ["image/png", "image/jpeg", "image/gif", "image/svg+xml", "image/webp", "image/tiff"]
  end

  @impl true
  def max_file_size do
    Bonfire.Files.normalise_size(
      Bonfire.Common.Config.get([:bonfire_files, :max_user_images_file_size]),
      5
    )
  end
end
