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
        for result <- stream do
          chunk(conn, prepare_rows(type, result))
        end
      end
    )
  end

  defp csv_content(conn, "followers" = type) do
    # ,"Show boosts","Notify on new posts","Languages"]
    fields = ["Account address"]

    current_user = current_user_required!(conn)

    {:ok, conn} = chunk(conn, [fields] |> CSV.dump_to_iodata())

    Bonfire.Social.Follows.list_my_followers(current_user,
      paginate: false,
      return: :stream,
      stream_callback: fn stream ->
        for result <- stream do
          chunk(conn, prepare_rows(type, result))
        end
      end
    )
  end

  defp csv_content(conn, "requests" = type) do
    # ,"Show boosts","Notify on new posts","Languages"]
    fields = ["Account address"]

    current_user = current_user_required!(conn)

    {:ok, conn} = chunk(conn, [fields] |> CSV.dump_to_iodata())

    Bonfire.Social.Requests.list_my_requested(
      current_user: current_user,
      type: Bonfire.Data.Social.Follow,
      paginate: false,
      return: :stream,
      stream_callback: fn stream ->
        for result <- stream do
          debug(result)
          chunk(conn, prepare_rows(type, result) |> debug())
        end
      end
    )
    |> debug()
  end

  defp csv_content(conn, type) do
    warn(type, "type not implemented")
    {:cont, conn}
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
