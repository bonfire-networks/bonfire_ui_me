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

  def json_download(conn, %{"type" => type} = _params) do
    conn
    |> put_resp_content_type("application/json")
    |> put_resp_header("content-disposition", "attachment; filename=\"export_#{type}.json\"")
    |> put_root_layout(false)
    |> send_chunked(:ok)
    # |> send_resp(200, csv_content(conn, type))
    |> json_content(type)
    |> ok_unwrap()
  end

  def binary_download(conn, %{"type" => type, "ext" => ext} = _params) do
    conn
    |> put_resp_content_type("application/octet-stream")
    |> put_resp_header("content-disposition", "attachment; filename=\"export_#{type}.#{ext}\"")
    |> put_root_layout(false)
    |> send_chunked(:ok)
    # |> send_resp(200, csv_content(conn, type))
    |> binary_content(type)
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
    file = zip_filename(id(current_user))

    conn
    |> put_resp_content_type("application/zip")
    |> put_resp_header(
      "content-disposition",
      "attachment; filename=\"bonfire_export_archive.zip\""
    )
    |> put_root_layout(false)
    |> Plug.Conn.send_file(200, file)
  end

  def archive_delete(conn, _params) do
    current_user = current_user_required!(conn)
    _file = archive_delete(id(current_user))

    conn
    |> Plug.Conn.send_resp(200, "Deleted")
  end

  def archive_exists?(current_user_id) when is_binary(current_user_id) do
    file = zip_filename(current_user_id)

    File.exists?(file)
  end

  def archive_delete(current_user_id) when is_binary(current_user_id) do
    file = zip_filename(current_user_id)

    File.rm!(file)
  end

  def archive_previous_date(current_user_id) when is_binary(current_user_id) do
    file = zip_filename(current_user_id)

    with {:ok, %{ctime: date}} <- File.stat(file, time: :posix) do
      date
      |> DateTime.from_unix!()
      |> debug
      |> DateTime.diff(DateTime.utc_now(), :day)
      |> debug
    else
      _ ->
        false
    end
  end

  def trigger_prepare_archive_async(context) do
    current_user = current_user_required!(context)

    apply_task(:start, fn ->
      # Process.sleep(5000) # for debug only
      Bonfire.UI.Me.ExportController.zip_archive(context, current_user)
    end)
  end

  def zip_archive(conn_or_context, user) do
    # name = String.trim_trailing("bonfire_export", ".zip")

    Zstream.zip(
      [
        Zstream.entry("actor.json", [actor(user)]),
        # TODO: optimise AP-based export
        # Zstream.entry("outbox.json", [
        #   collection_header("outbox"),
        #   ok_unwrap(outbox(user)),
        #   collection_footer()
        # ]),
        Zstream.entry("following.csv", ok_unwrap(csv_content(user, "following"))),
        Zstream.entry("requests.csv", ok_unwrap(csv_content(user, "requests"))),
        Zstream.entry("followers.csv", ok_unwrap(csv_content(user, "followers"))),
        Zstream.entry("posts.csv", ok_unwrap(csv_content(user, "posts"))),
        Zstream.entry("messages.csv", ok_unwrap(csv_content(user, "messages"))),
        Zstream.entry("ghosted.csv", ok_unwrap(csv_content(user, "ghosted"))),
        Zstream.entry("silenced.csv", ok_unwrap(csv_content(user, "silenced"))),
        Zstream.entry("keys.asc", [keys(user)])
      ] ++
        for {path, uri} <- user_media(user) do
          media_stream(path, uri, &Zstream.entry/2)
        end
    )
    |> zip_stream_process(id(user), conn_or_context)
  end

  defp zip_stream_process(stream, _, %Plug.Conn{} = conn) do
    stream
    |> Enum.reduce_while(conn, fn result, conn ->
      case maybe_chunk(conn, result) do
        {:ok, conn} ->
          {:cont, conn}

        other ->
          IO.inspect(other, label: "unexpected zip_stream_process with conn")
          {:halt, conn}
      end
    end)
  end

  defp zip_stream_process(stream, user_id, context) do
    {path, file} = zip_path_file(user_id)

    # just in case
    File.rm(file)

    with :ok <- File.mkdir_p(path),
         :ok <-
           stream
           |> Stream.into(File.stream!(file))
           |> Stream.run() do
      Bonfire.UI.Common.PersistentLive.notify(context, %{
        title: l("Your archive is ready"),
        message:
          "<a href='/settings/export/archive_download' download class='btn btn-success'>Download it here</a>"
      })

      :ok
    else
      other ->
        IO.inspect(other, label: "unexpected zip_stream_process without conn")

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

  defp zip_filename(user_id) do
    {_path, file} =
      zip_path_file(user_id)
      |> debug()

    file
  end

  defp json_content(conn_or_user, "outbox" = type) do
    {:ok, _conn} = maybe_chunk(conn_or_user, collection_header(type))

    {:ok, _conn} = outbox(conn_or_user)

    {:ok, _conn} = maybe_chunk(conn_or_user, collection_footer())
  end

  defp json_content(conn_or_user, "actor" = _type) do
    {:ok, _conn} = maybe_chunk(conn_or_user, actor(conn_or_user))
  end

  defp binary_content(conn_or_user, "private_key" = _type) do
    {:ok, _conn} = maybe_chunk(conn_or_user, private_key(conn_or_user))
  end

  defp binary_content(conn_or_user, "keys" = _type) do
    {:ok, _conn} = maybe_chunk(conn_or_user, keys(conn_or_user))
  end

  defp outbox(conn_or_user) do
    Process.put(:federating, :manual)

    user = current_user(conn_or_user)

    feed_id = Bonfire.Social.Feeds.feed_id(:outbox, user)

    Bonfire.Social.FeedActivities.feed(feed_id,
      paginate: false,
      preload: [],
      exclude_verbs: false,
      current_user: user,
      return: :stream,
      stream_callback: fn stream ->
        stream_callback("outbox", stream, conn_or_user)
      end
    )

    # |> IO.inspect(label: "outbx")
  end

  defp csv_content(conn, "following" = type) do
    # ,"Show boosts","Notify on new posts","Languages"]
    fields = ["Account address"]

    current_user = current_user_required!(conn)

    {:ok, conn} = maybe_chunk(conn, [fields] |> CSV.dump_to_iodata())

    Utils.maybe_apply(
      Bonfire.Social.Graph.Follows,
      :list_my_followed,
      [
        current_user,
        [
          paginate: false,
          return: :stream,
          stream_callback: fn stream ->
            stream_callback(type, stream, conn)
          end
        ]
      ]
    )

    # |> IO.inspect(label: "folg")
  end

  defp csv_content(conn, "followers" = type) do
    fields = ["Account address"]

    current_user = current_user_required!(conn)

    {:ok, conn} = maybe_chunk(conn, [fields] |> CSV.dump_to_iodata())

    Utils.maybe_apply(
      Bonfire.Social.Graph.Follows,
      :list_my_followers,
      [
        current_user,
        [
          paginate: false,
          return: :stream,
          stream_callback: fn stream ->
            stream_callback(type, stream, conn)
          end
        ]
      ]
    )

    # |> IO.inspect(label: "fols")
  end

  defp csv_content(conn, "requests" = type) do
    fields = ["Account address"]

    current_user = current_user_required!(conn)

    {:ok, conn} = maybe_chunk(conn, [fields] |> CSV.dump_to_iodata())

    Utils.maybe_apply(
      Bonfire.Social.Graph.Requests,
      :list_my_requested,
      current_user: current_user,
      type: Bonfire.Data.Social.Follow,
      paginate: false,
      return: :stream,
      stream_callback: fn stream ->
        stream_callback(type, stream, conn)
      end
    )

    # |> IO.inspect(label: "req")
  end

  defp csv_content(conn, "posts" = type) do
    fields = ["ID", "Date", "CW", "Summary", "Text"]

    current_user = current_user_required!(conn)

    {:ok, conn} = maybe_chunk(conn, [fields] |> CSV.dump_to_iodata())

    Utils.maybe_apply(
      Bonfire.Posts,
      :list_by,
      [
        current_user,
        [
          current_user: current_user,
          paginate: false,
          return: :stream,
          stream_callback: fn stream ->
            stream_callback(type, stream, conn)
          end
        ]
      ]
    )
  end

  defp csv_content(conn, "messages" = type) do
    fields = ["ID", "Date", "From", "To", "CW", "Summary", "Text"]

    current_user = current_user_required!(conn)

    {:ok, conn} = maybe_chunk(conn, [fields] |> CSV.dump_to_iodata())

    Utils.maybe_apply(
      Bonfire.Messages,
      :list,
      [
        current_user,
        nil,
        [
          paginate: false,
          return: :stream,
          stream_callback: fn stream ->
            stream_callback(type, stream, conn)
          end
        ]
      ],
      fallback_return: []
    )

    # |> IO.inspect(label: "msgs")
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
    # |> IO.inspect(label: "bloq")
    |> maybe_chunk(conn, ...)
  end

  defp csv_content(conn, type) do
    IO.inspect(type, label: "type not implemented")
    conn
  end

  defp stream_callback(type, stream, %Plug.Conn{} = conn) do
    # for result <- stream do
    #   maybe_chunk(conn, prepare_rows(type, result))
    # end
    Enum.reduce_while(stream, conn, fn result, conn ->
      case maybe_chunk(conn, prepare_rows(type, result)) do
        {:ok, conn} ->
          {:cont, conn}

        other ->
          IO.inspect(other, label: "unexpected stream_callback")
          {:halt, conn}
      end
    end)
  end

  defp stream_callback(type, stream, _user) do
    prepare_rows(type, stream)
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

  defp preload_assocs(records, type) when type in ["messages"] do
    # records |> repo().preload([:post_content, :peered, created: [creator: [:character]]])

    Bonfire.Social.Activities.activity_preloads(
      records,
      [:with_object_posts, :with_subject, :with_reply_to, :tags],
      skip_boundary_check: true
    )
  end

  defp preload_assocs(records, type) when type in ["posts"] do
    records |> repo().preload([:post_content, :peered])
  end

  #   defp preload_assocs(records, type) when type in ["outbox"] do
  #     records |> repo().preload([:activity])
  #   end
  defp preload_assocs(records, _type) do
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

    # |> debug()

    [
      URIs.canonical_url(record),
      DatesTimes.date_from_pointer(record),
      e(record, :post_content, :name, nil),
      e(record, :post_content, :summary, nil),
      e(record, :post_content, :html_body, nil)
    ]
  end

  defp prepare_record(type, record) when type in ["messages"] do
    record =
      record
      |> preload_assocs(type)
      |> debug()

    participants =
      Utils.maybe_apply(
        Bonfire.Messages.LiveHandler,
        :thread_participants,
        [nil, record, nil, []]
      )
      |> debug()

    msg = e(record, :activity, :object, :post_content, nil) || e(record, :post_content, nil)

    [
      URIs.canonical_url(record),
      DatesTimes.date_from_pointer(record),
      e(record, :activity, :subject, :character, :username, nil),
      Enum.map(participants, &e(&1, :character, :username, nil)) |> Enum.join(" ; "),
      e(msg, :name, nil),
      e(msg, :summary, nil),
      e(msg, :html_body, nil)
    ]
  end

  defp prepare_record(type, record) when type in ["outbox"] do
    # activity =
    #   record
    #   |> preload_assocs(type)
    #   |> e(:activity, nil)

    with {:ok, json} <-
           ActivityPub.Web.ActivityPubController.json_object_with_cache(nil, id(record),
             exporting: true
           ) do
      """
      #{json},
      """
    else
      _ ->
        ""
    end

    # |> IO.inspect(label: "jsssson")
  end

  defp prepare_csv(records) do
    records
    |> CSV.dump_to_iodata()

    # |> IO.iodata_to_binary()
  end

  defp actor(conn_or_user) do
    with {:ok, actor} = ActivityPub.Actor.get_cached(pointer: current_user(conn_or_user)),
         {:ok, json} <-
           ActivityPub.Web.ActorView.render("actor.json", %{actor: actor})
           #    |> Map.merge(%{"likes" => "likes.json", "bookmarks" => "bookmarks.json"})
           |> Jason.encode() do
      json
    end
  end

  defp private_key(conn_or_user) do
    current_user(conn_or_user)
    |> repo().maybe_preload(character: [:actor])
    |> e(:character, :actor, :signing_key, nil)

    # |> debug()
  end

  defp keys(conn_or_user) do
    keys = private_key(conn_or_user)

    """
    #{keys}

    #{ok_unwrap(ActivityPub.Safety.Keys.public_key_from_data(%{keys: keys}))}
    """
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

  def user_media(user) do
    user_id = id(user)

    Bonfire.Files.Media.many(user: user_id)
    ~> Enum.map(fn
      %{path: "http" <> _ = uri, id: id} = _media ->
        {"/data/links/#{id}.html", uri}

      %{file: %{id: path} = locator} = _media ->
        # debug(path)
        {path, locator}

      media ->
        path =
          case Bonfire.Files.remote_url(media)
               |> debug() do
            nil -> nil
            path -> String.trim(path, "/")
          end

        if not is_nil(path) and File.exists?(path), do: {path, path}
    end)
    |> Enums.filter_empty([])
  end

  def media_stream(path, "http" <> _ = uri, fun) do
    fun.(path, ["<!DOCTYPE HTML>
    <html>
      <head>
        <title>Automatic redirect to #{uri}</title>
        <meta http-equiv=\"refresh\" content=\"0; url=#{uri}\" />
      </head>
      <body>
        <h1>For older browsers, click Redirect</h1>
        <p><a href=\"#{uri}\">Redirect</a></p>
      </body>
    </html>"])
  end

  # def media_stream(path, %Entrepot.Locator{storage: storage} = locator, fun) when storage in [Entrepot.Storages.Disk, "Elixir.Entrepot.Storages.Disk"] do
  #  # stream files from Disk
  #   path = Entrepot.Storages.Disk.path(locator)

  #   if is_binary(path) and File.exists?(path) do
  #     fun.(path, File.stream!(path, [], 512))
  #   else
  #     fun.("#{path}.txt", ["File not found"])
  #   end
  # end
  def media_stream(path, %Entrepot.Locator{id: id} = locator, fun) do
    # stream files from Disk or S3
    source_storage = Entrepot.storage!(locator)

    case source_storage.stream(id) do
      nil -> fun.("#{path}.txt", ["File not found"])
      stream -> fun.(path, stream)
    end
  end

  # def media_stream(path, %Entrepot.Locator{} = locator, fun) do
  #  # copy S3 files to Disk
  #   with {:ok, new_locator} <- Entrepot.copy(locator, Entrepot.Storages.Disk, skip_existing: true)
  #     |> debug() do
  #     media_stream(path, new_locator, fun)
  #   else
  #     {:error, error} when is_binary(error) -> fun.("#{path}.txt", [error])
  #     other -> raise other
  #   end
  # end
  def media_stream(path, path, fun) when is_binary(path) do
    fun.(path, File.stream!(path, [], 512))
  end

  # defp likes(user) do
  #   user.ap_id
  #   |> Activity.Queries.by_actor()
  #   |> Activity.Queries.by_type("Like")
  #   |> select([like], %{id: like.id, object: fragment("(?)->>'object'", like.data)})
  #   |> output("likes", fn a -> {:ok, a.object} end)
  # end
end
