defmodule Bonfire.UI.Me.ExportController do
  use Bonfire.UI.Common.Web, :controller

  alias NimbleCSV.RFC4180, as: CSV

  # TODO: move some of the logic to backend module(s)

  def csv_download(conn, %{"type" => type} = _params) do
    conn
    |> put_resp_content_type("text/csv")
    |> put_resp_header("content-disposition", "attachment; filename=\"export_#{type}.csv\"")
    |> put_root_layout(false)
    |> send_chunked(:ok)
    # |> send_resp(200, csv_content(conn, type))
    |> csv_content(type)
    |> ok_unwrap()
  end

  def archive_export(conn, _params) do
    conn
    |> put_resp_content_type("application/zip")
    |> put_resp_header(
      "content-disposition",
      "attachment; filename=\"bonfire_export_archive.zip\""
    )
    |> put_root_layout(false)
    |> send_chunked(:ok)
    # |> send_resp(200, csv_content(conn, type))
    |> zip_archive(current_user_required!(conn))
    |> ok_unwrap()
  end

  def archive_download(conn, _params) do
    current_user = current_user_required!(conn)
    {_path, file} = zip_path_file(id(current_user))

    conn
    |> put_resp_content_type("application/zip")
    |> put_resp_header(
      "content-disposition",
      "attachment; filename=\"bonfire_export_archive.zip\""
    )
    |> put_root_layout(false)
    |> Plug.Conn.send_file(200, file)
  end

  def trigger_prepare_archive_async(context) do
    current_user = current_user_required!(context)
    Task.async(fn -> Bonfire.UI.Me.ExportController.zip_archive(context, current_user) end)
  end

  def zip_archive(conn_or_context, user) do
    name = String.trim_trailing("bonfire_export", ".zip")

    {:ok, actor} = ActivityPub.Actor.get_cached(pointer: user)

    uploads = media(user)

    Zstream.zip(
      [
        Zstream.entry("actor.json", [actor(actor)]),
        Zstream.entry("outbox.json", [
          collection_header("outbox"),
          ok_unwrap(outbox(user)),
          collection_footer()
        ]),
        Zstream.entry("following.csv", ok_unwrap(csv_content(user, "following"))),
        Zstream.entry("requests.csv", ok_unwrap(csv_content(user, "requests"))),
        Zstream.entry("followers.csv", ok_unwrap(csv_content(user, "followers"))),
        Zstream.entry("posts.csv", ok_unwrap(csv_content(user, "posts"))),
        Zstream.entry("ghosted.csv", ok_unwrap(csv_content(user, "ghosted"))),
        Zstream.entry("silenced.csv", ok_unwrap(csv_content(user, "silenced")))
      ] ++
        for upload <- uploads do
          Zstream.entry(upload, File.stream!(upload, [], 512))
        end
    )
    |> zip_stream_process(id(user), conn_or_context)
  end

  defp zip_stream_process(stream, _, %Plug.Conn{} = conn) do
    debug("download by chunks")

    stream
    |> Enum.reduce_while(conn, fn result, conn ->
      # debug(result)

      case maybe_chunk(conn, result) do
        {:ok, conn} ->
          {:cont, conn}

        other ->
          error(other)
          {:halt, conn}
      end
    end)
  end

  defp zip_stream_process(stream, user_id, context) do
    {path, file} = zip_path_file(user_id)

    with :ok <- File.mkdir_p(path),
         :ok <-
           stream
           |> Stream.into(File.stream!(file))
           |> Stream.run()
           |> debug() do
      debug("ZIP done")

      Bonfire.UI.Common.PersistentLive.notify(context, %{
        title: l("Your archive is ready"),
        message:
          "<a href='/settings/export/archive_download' download class='btn btn-success'>Download it here</a>"
      })

      :ok
    else
      other ->
        error(other)

        Bonfire.UI.Common.PersistentLive.notify(context, %{
          title: l("Error preparing your archive"),
          message: inspect(other)
        })
    end
  end

  defp zip_path_file(user_id) do
    path = "/tmp/#{user_id}"

    {path, "#{path}/archive.zip"}
  end

  defp outbox(user) do
    feed_id = Bonfire.Social.Feeds.feed_id(:outbox, user)

    Bonfire.Social.FeedActivities.feed(feed_id,
      paginate: false,
      current_user: user,
      return: :stream,
      stream_callback: fn stream ->
        stream_callback("outbox", stream, user)
      end
    )
    |> IO.inspect(label: "outbx")
  end

  defp csv_content(conn, "following" = type) do
    # ,"Show boosts","Notify on new posts","Languages"]
    fields = ["Account address"]

    current_user = current_user_required!(conn)

    {:ok, conn} = maybe_chunk(conn, [fields] |> CSV.dump_to_iodata())

    Bonfire.Social.Follows.list_my_followed(current_user,
      paginate: false,
      return: :stream,
      stream_callback: fn stream ->
        stream_callback(type, stream, conn)
      end
    )
    |> IO.inspect(label: "folg")
  end

  defp csv_content(conn, "followers" = type) do
    fields = ["Account address"]

    current_user = current_user_required!(conn)

    {:ok, conn} = maybe_chunk(conn, [fields] |> CSV.dump_to_iodata())

    Bonfire.Social.Follows.list_my_followers(current_user,
      paginate: false,
      return: :stream,
      stream_callback: fn stream ->
        stream_callback(type, stream, conn)
      end
    )
    |> IO.inspect(label: "fols")
  end

  defp csv_content(conn, "requests" = type) do
    fields = ["Account address"]

    current_user = current_user_required!(conn)

    {:ok, conn} = maybe_chunk(conn, [fields] |> CSV.dump_to_iodata())

    Bonfire.Social.Requests.list_my_requested(
      current_user: current_user,
      type: Bonfire.Data.Social.Follow,
      paginate: false,
      return: :stream,
      stream_callback: fn stream ->
        stream_callback(type, stream, conn)
      end
    )
    |> IO.inspect(label: "req")
  end

  defp csv_content(conn, "posts" = type) do
    fields = ["ID", "Date", "CW", "Summary", "Text"]

    current_user = current_user_required!(conn)

    {:ok, conn} = maybe_chunk(conn, [fields] |> CSV.dump_to_iodata())

    Bonfire.Social.Posts.list_by(current_user,
      current_user: current_user,
      paginate: false,
      return: :stream,
      stream_callback: fn stream ->
        stream_callback(type, stream, conn)
      end
    )
    |> IO.inspect(label: "postss")
  end

  defp csv_content(conn, type) when type in ["silenced", "ghosted"] do
    fields = ["Account address"]
    current_user = current_user_required!(conn)
    scope = nil

    block_type = if type == "ghosted", do: :ghost, else: :silence

    {:ok, conn} = maybe_chunk(conn, [fields] |> CSV.dump_to_iodata())

    if scope == :instance_wide do
      Bonfire.Boundaries.Blocks.instance_wide_circles(block_type)
    else
      Bonfire.Boundaries.Blocks.user_block_circles(scope || current_user, block_type)
    end
    |> List.first()
    |> repo().maybe_preload(encircles: [subject: [:character]])
    |> e(:encircles, [])
    |> prepare_rows(type, ...)
    |> IO.inspect(label: "bloq")
    |> maybe_chunk(conn, ...)
  end

  defp csv_content(conn, type) do
    warn(type, "type not implemented")
    conn
  end

  defp stream_callback(type, stream, %Plug.Conn{} = conn) do
    # for result <- stream do
    #   maybe_chunk(conn, prepare_rows(type, result) |> debug())
    # end
    Enum.reduce_while(stream, conn, fn result, conn ->
      debug(result)

      case maybe_chunk(conn, prepare_rows(type, result) |> debug()) do
        {:ok, conn} ->
          {:cont, conn}

        other ->
          error(other)
          {:halt, conn}
      end
    end)
  end

  defp stream_callback(type, stream, user) do
    prepare_rows(type, stream)
    |> debug()
  end

  defp maybe_chunk(%Plug.Conn{} = conn, data) do
    Plug.Conn.chunk(conn, data)
  end

  defp maybe_chunk(_conn, data) do
    {:ok, data}
  end

  defp prepare_rows("outbox" = type, records) when is_list(records) do
    records |> preload_assocs(type) |> Enum.map(&prepare_record(type, &1))
  end

  defp prepare_rows("outbox" = type, %Stream{} = stream) do
    stream
    |> Enum.map(&prepare_record(type, &1))
  end

  defp prepare_rows("outbox" = type, record) do
    prepare_record(type, record)
  end

  defp prepare_rows(type, records) when is_list(records) do
    records |> preload_assocs(type) |> Enum.map(&prepare_record(type, &1)) |> prepare_csv()
  end

  defp prepare_rows(type, %Stream{} = stream) do
    stream
    |> Enum.map(&prepare_record(type, &1))
    |> prepare_csv()
  end

  defp prepare_rows(type, record) when is_struct(record) do
    [prepare_record(type, record)]
    |> prepare_csv()
  end

  defp preload_assocs(records, type) when type in ["following", "requests"] do
    records |> repo().preload(edge: [object: [:character]])
  end

  defp preload_assocs(records, type) when type in ["followers"] do
    records |> repo().preload(edge: [subject: [:character]])
  end

  defp preload_assocs(records, type) when type in ["posts"] do
    records |> repo().preload([:post_content, :peered])
  end

  #   defp preload_assocs(records, type) when type in ["outbox"] do
  #     records |> repo().preload([:activity])
  #   end
  defp preload_assocs(records, type) do
    records
  end

  defp prepare_record(type, record) when type in ["following", "requests"] do
    [
      record
      |> preload_assocs(type)
      |> e(:edge, :object, nil)
      |> Bonfire.Me.Characters.display_username(true)
    ]
  end

  defp prepare_record(type, record) when type in ["followers"] do
    [
      record
      |> preload_assocs(type)
      |> e(:edge, :subject, nil)
      |> Bonfire.Me.Characters.display_username(true)
    ]
  end

  defp prepare_record(type, record) when type in ["silenced", "ghosted"] do
    [
      record
      |> e(:subject, nil)
      |> Bonfire.Me.Characters.display_username(true)
    ]
  end

  defp prepare_record(type, record) when type in ["posts"] do
    record =
      record
      |> preload_assocs(type)
      |> debug()

    [
      URIs.canonical_url(record),
      DatesTimes.date_from_pointer(record),
      e(record, :post_content, :name, nil),
      e(record, :post_content, :summary, nil),
      e(record, :post_content, :html_body, nil)
    ]
  end

  defp prepare_record(type, record) when type in ["outbox"] do
    # activity =
    #   record
    #   |> preload_assocs(type)
    #   |> e(:activity, nil)
    #   |> debug()

    with {:ok, json} <- ActivityPub.Web.ActivityPubController.json_object_with_cache(id(record)) do
      """
      #{json},
      """
    else
      _ ->
        ""
    end
    |> debug("jsssson")
  end

  defp prepare_csv(records) do
    records
    |> debug()
    |> CSV.dump_to_iodata()

    # |> IO.iodata_to_binary()
  end

  defp actor(actor) do
    with {:ok, json} <-
           ActivityPub.Web.ActorView.render("actor.json", %{actor: actor})
           #    |> Map.merge(%{"likes" => "likes.json", "bookmarks" => "bookmarks.json"})
           |> Jason.encode() do
      json
    end
  end

  defp collection_header(name) do
    """
    {
      "@context": "https://www.w3.org/ns/activitystreams",
      "id": "#{name}.json",
      "type": "OrderedCollection",
      "orderedItems": [
    """
  end

  defp collection_footer() do
    "  {}\n]}"
  end

  def media(user) do
    Bonfire.Files.Media.many(user: id(user))
    ~> Enum.map(&Bonfire.Files.remote_url/1)
    |> Enums.filter_empty([])
    |> Enum.map(&String.trim(&1, "/"))
    |> Enum.reject(fn
      # TODO: support uploads in CDN
      "http" <> _ ->
        true

      path ->
        !File.exists?(path)
    end)
  end

  # defp likes(user) do
  #   user.ap_id
  #   |> Activity.Queries.by_actor()
  #   |> Activity.Queries.by_type("Like")
  #   |> select([like], %{id: like.id, object: fragment("(?)->>'object'", like.data)})
  #   |> output("likes", fn a -> {:ok, a.object} end)
  # end
end
