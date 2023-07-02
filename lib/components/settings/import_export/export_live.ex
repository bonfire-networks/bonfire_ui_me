defmodule Bonfire.UI.Me.SettingsViewsLive.ExportLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop selected_tab, :string
end

defmodule Bonfire.UI.Me.ExportController do
  use Bonfire.UI.Common.Web, :controller

  alias NimbleCSV.RFC4180, as: CSV

  def download(conn, %{"type" => type} = _params) do
    conn
    |> put_resp_content_type("text/csv")
    |> put_resp_header("content-disposition", "attachment; filename=\"export_#{type}.csv\"")
    |> put_root_layout(false)
    |> send_chunked(:ok)
    # |> send_resp(200, csv_content(conn, type))
    |> csv_content(type)
    |> ok_unwrap()
  end

  defp csv_content(conn, "following" = type) do
    # ,"Show boosts","Notify on new posts","Languages"]
    fields = ["Account address"]

    current_user = current_user_required!(conn)

    {:ok, conn} = chunk(conn, [fields] |> CSV.dump_to_iodata())

    Bonfire.Social.Follows.list_my_followed(current_user,
      paginate: false,
      return: :stream,
      stream_callback: fn stream ->
        stream_callback(type, stream, conn)
      end
    )
  end

  defp csv_content(conn, "followers" = type) do
    fields = ["Account address"]

    current_user = current_user_required!(conn)

    {:ok, conn} = chunk(conn, [fields] |> CSV.dump_to_iodata())

    Bonfire.Social.Follows.list_my_followers(current_user,
      paginate: false,
      return: :stream,
      stream_callback: fn stream ->
        stream_callback(type, stream, conn)
      end
    )
  end

  defp csv_content(conn, "requests" = type) do
    fields = ["Account address"]

    current_user = current_user_required!(conn)

    {:ok, conn} = chunk(conn, [fields] |> CSV.dump_to_iodata())

    Bonfire.Social.Requests.list_my_requested(
      current_user: current_user,
      type: Bonfire.Data.Social.Follow,
      paginate: false,
      return: :stream,
      stream_callback: fn stream ->
        stream_callback(type, stream, conn)
      end
    )
    |> debug()
  end

  defp csv_content(conn, type) when type in ["silenced", "ghosted"] do
    fields = ["Account address"]
    current_user = current_user_required!(conn)
    scope = nil

    block_type = if type == "ghosted", do: :ghost, else: :silence

    {:ok, conn} = chunk(conn, [fields] |> CSV.dump_to_iodata())

    if scope == :instance_wide do
      Bonfire.Boundaries.Blocks.instance_wide_circles(block_type)
    else
      Bonfire.Boundaries.Blocks.user_block_circles(scope || current_user, block_type)
    end
    |> List.first()
    |> repo().maybe_preload(encircles: [subject: [:character]])
    |> e(:encircles, [])
    |> prepare_rows(type, ...)
    |> debug
    |> Plug.Conn.chunk(conn, ...)
  end

  defp csv_content(conn, type) do
    warn(type, "type not implemented")
    conn
  end

  defp stream_callback(type, stream, conn) do
    # for result <- stream do
    #   debug(result)
    #   Plug.Conn.chunk(conn, prepare_rows(type, result) |> debug())
    # end
    Enum.reduce_while(stream, conn, fn result, conn ->
      case Plug.Conn.chunk(conn, prepare_rows(type, result) |> debug()) do
        {:ok, conn} ->
          {:cont, conn}

        other ->
          error(other)
          {:halt, conn}
      end
    end)
  end

  defp prepare_rows(type, records) when is_list(records) do
    prepare_csv(records |> preload_assocs(type) |> Enum.map(&prepare_record(type, &1)))
  end

  defp prepare_rows(type, record) do
    prepare_csv([prepare_record(type, record)])
  end

  defp prepare_record(type, record) when type in ["following", "requests"] do
    [
      record
      |> preload_assocs(type)
      |> e(:edge, :object, nil)
      |> debug()
      |> Bonfire.Me.Characters.display_username(true)
    ]
  end

  defp prepare_record(type, record) when type in ["followers"] do
    [
      record
      |> preload_assocs(type)
      |> e(:edge, :subject, nil)
      |> debug()
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

  defp preload_assocs(records, type) when type in ["following", "requests"] do
    records |> repo().preload(edge: [object: [:character]])
  end

  defp preload_assocs(records, type) when type in ["followers"] do
    records |> repo().preload(edge: [subject: [:character]])
  end

  defp preload_assocs(records, type) do
    records
  end

  defp prepare_csv(records) do
    records
    |> debug()
    |> CSV.dump_to_iodata()

    # |> IO.iodata_to_binary()
  end
end
