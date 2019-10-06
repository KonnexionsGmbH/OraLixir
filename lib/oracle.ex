defmodule Oracle.Error do
  defexception [:message]
end

defmodule Oracle.Result do
  defstruct [:columns, :rows]
end

defmodule Oracle.Query do
  defstruct [:query_str, :statement, :numCols]

  defimpl DBConnection.Query do
    def parse(query, _opts), do: query
    def describe(query, _opts), do: query
    def encode(_query, params, _opts), do: params
    def decode(_query, result, _opts), do: result
  end
end

defmodule Oracle.Protocol do
  @moduledoc """

  Adapter module for Oracle. `DBConnection` behaviour implementation.

  It uses `oranif` for communicating to the database.

  # DPI_MAJOR_VERSION and DPI_MINOR_VERSION
  # define https://github.com/oracle/odpi/blob/v3.0.0/include/dpi.h#L46-L47
  """

  @dpiMajorVersion 3
  @dpiMinorVersion 0

  use DBConnection

  defstruct [:oranifNode, :context, :conn]
  
  defmacrop oranif(slave, api, args) do
    quote do
      try do
        case unquote(slave) do
          nil -> Kernel.apply(:dpi, unquote(api), unquote(args))
          _ -> :rpc.call(unquote(slave), :dpi, unquote(api), unquote(args))
        end
      rescue
        e in ErlangError ->
          {:error, file, line, original} = e.original
          {:error, %{
            reason: original,
            oranifFile: file,
            oranifLine: line,
            api: unquote(api),
            args: unquote(args),
            node: unquote(slave)
          }}
      end
    end
  end

  @impl true
  def checkin(s) do
    {:ok, s}
  end

  @impl true
  def checkout(s) do
    {:ok, s}
  end
  
  @impl true
  def connect(opts) do
    true = Keyword.has_key?(opts, :userName)
    true = Keyword.has_key?(opts, :password)

    ora = %Oracle.Protocol{}
  
    case Keyword.fetch(opts, :slave) do
      {:ok, slave} -> :dpi.load slave
      :error -> :dpi.load_unsafe
    end
    |>
    case do
      :ok -> create_context_connection ora, opts
      slave when is_atom(slave) ->
        create_context_connection %{ora | oranifNode: slave}, opts
      error -> {:error, error}
    end
  end

  @impl true
  def disconnect(_err, ora) do
    IO.inspect ora
    if ora.conn != nil, do: oranif(ora.oranifNode, :conn_close, [ora.conn, [], ""])
    if ora.context != nil, do: oranif(ora.oranifNode, :context_destroy, [ora.context])
    if ora.oranifNode != node(), do: :dpi.unload ora.oranifNode
    :ok
  end

  @impl true
  def handle_begin(_opts, s) do
    {:ok, :handle_begin, s}
  end

  @impl true
  def handle_close(_query, _opts, state) do
    {:ok, :handle_close, state}
  end

  @impl true
  def handle_commit(_opts, state) do
    {:ok, :handle_commit, state}
  end

  @impl true
  def handle_deallocate(_query, _cursor, _opts, state) do
    {:ok, :handle_deallocate, state}
  end

  @impl true
  def handle_declare(
    %Oracle.Query{statement: statement} = query, _params, _opts, %Oracle.Protocol{oranifNode: slave} = state
  ) do
    case oranif(slave, :stmt_execute, [statement, []]) do
      numberOfColumns when is_integer(numberOfColumns) ->
        query = %{query | numCols: numberOfColumns}
        {:ok, query, statement, state}
      error ->
        {
          :error,
          %Oracle.Error{message: "error when executing query: #{error}"},
          state
        }
    end
  end

  @impl true
  def handle_fetch(
    %Oracle.Query{numCols: numberOfColumns}, statement, _opts, %Oracle.Protocol{oranifNode: slave} = state
  ) do
    case oranif(slave, :stmt_fetch, [statement]) do
      %{found: true} ->          
          {:cont, fetch_row(numberOfColumns, slave, statement, []), state}
      %{found: false} ->
          {:halt, :halt, state}
      error ->
        {
          :error,
          %Oracle.Error{message: "error when executing query: #{error}"},
          state
        }
    end
  end

  @impl true
  def handle_execute(
    %Oracle.Query{statement: statement} = query, _params, _opts,
    %Oracle.Protocol{oranifNode: slave} = state
  ) when is_reference(statement)
  do
    case oranif(slave, :stmt_execute, [statement, []]) do
      numberOfColumns when is_integer(numberOfColumns) ->
        columns = for idx <- 1..numberOfColumns do
          case oranif(slave, :stmt_getQueryInfo, [statement, idx]) do
            col when is_map(col) -> col
            error ->
              raise error
          end          
        end
        rows = fetch_all(slave, statement, numberOfColumns)
        result = %Oracle.Result{columns: columns, rows: rows}
        {:ok, %{query | numCols: numberOfColumns}, result, state}
      error ->
        {
          :error,
          %Oracle.Error{message: "error when executing query: #{error}"},
          state
        }
    end
  end
  
  @impl true
  def handle_prepare(
    %Oracle.Query{query_str: queryStr} = query, _opts,
    %Oracle.Protocol{conn: conn, oranifNode: slave} = state
  ) do
    case oranif(slave, :conn_prepareStmt, [conn, false, queryStr, <<>>]) do
      statement when is_reference(statement) ->
        query = %{query | statement: statement}
        {:ok, query, state}
      error ->
        {
          :error,
          %Oracle.Error{message: "error when preparing query: #{error}"},
          state
        }
    end
  end

  @impl true
  def handle_rollback(
    _opts,
    %Oracle.Protocol{conn: conn, oranifNode: slave} = state
  ) do
    case oranif(slave, :conn_rollback, [conn]) do
      :ok -> {:ok, :ok, state}
      error -> {:disconnect, error, state}
    end
    {:ok, :handle_rollback, state}
  end

  @impl true
  def handle_status(_opts, state) do
    {:idle, state}
    # TODO
    # https://hexdocs.pm/db_connection/DBConnection.html#c:handle_status/2
  end

  @impl true
  def ping(%Oracle.Protocol{conn: conn, oranifNode: slave} = state) do
    case oranif(slave, :conn_ping, [conn]) do
      :ok -> {:ok, state}
      error -> {:disconnect, error, state}
    end
  end

  defp create_context_connection(ora, opts) do
    userName = Keyword.fetch!(opts, :userName)
    password = Keyword.fetch!(opts, :password)

    connectString = case Keyword.fetch(opts, :connectString) do
      {:ok, connStr} -> connStr
      :error ->
        port = Keyword.fetch!(opts, :port)
        host = Keyword.fetch!(opts, :hostname)
        service_name = Keyword.fetch!(opts, :service_name)
        """
        (DESCRIPTION=(ADDRESS_LIST=(ADDRESS=(PROTOCOL=TCP)(HOST=#{host})
        (PORT=#{port})))(CONNECT_DATA=(SERVER=dedicated)
        (SERVICE_NAME=#{service_name})))
        """
    end

    commonParams = Keyword.get(opts, :commonParams, %{})
    createParams = Keyword.get(opts, :createParams, %{})

    oranif(
      ora.oranifNode, :context_create, [@dpiMajorVersion, @dpiMinorVersion]
    ) |>
    case do
      {:error, reason} -> {:error, reason}
      context ->
        oranif(
          ora.oranifNode, :conn_create,
          [
            context, userName, password, connectString, commonParams,
            createParams
          ]
        ) |>
        case do
          {:error, reason} -> {:error, reason}
          conn ->
            %{ora | context: context, conn: conn}
        end
    end |>
    case do
      {:error, reason} ->
        if ora.conn != nil, do: oranif(ora.oranifNode, :conn_close, [ora.conn, [], ""])
        if ora.context != nil, do: oranif(ora.oranifNode, :context_destroy, [ora.context])
        if ora.oranifNode != node(), do: :dpi.unload ora.oranifNode
        {:error, reason}
      newora -> {:ok, newora}
    end
  end

  defp fetch_all(slave, statement, numberOfColumns) do
    case oranif(slave, :stmt_fetch, [statement]) do
      %{found: false} -> []
      %{found: true} ->
        [fetch_row(numberOfColumns, slave, statement, [])
         | fetch_all(slave, statement, numberOfColumns)]
    end
  end

  defp fetch_row(0, _slave, statement, row), do: row
  defp fetch_row(colIdx, slave, statement, row) do
    %{data: data} = oranif(slave, :stmt_getQueryValue, [statement, colIdx])
    value = oranif(slave, :data_get, [data])
    oranif(slave, :data_release, [data])
    fetch_row(colIdx - 1, slave, statement, [value | row])
  end

end

defmodule Oracle do
  @moduledoc """

  opts = [
    hostname: "127.0.0.1",
    port: 1521,
    service_name: "XE",
    userName: "scott",
    password: "regit",
  ]
  {:ok, pid} = Oracle.start_link(opts)
  Oracle.prepare_execute(pid, "name", "SELECT 'string', 1, sysdate FROM DUAL", [], [])
  Oracle.prepare_stream(pid, "SELECT * FROM AAATRACKING", [], [])
  """

  def start_link(opts) do
    DBConnection.start_link(Oracle.Protocol, opts)
  end

  def prepare_execute(conn, _name, query_str, params, opts) do
    query = %Oracle.Query{query_str: query_str}
    {:ok, statement, result} = DBConnection.prepare_execute(conn, query, params, opts)
    DBConnection.close(conn, query)
    columnNames = for %{name: name} <- result.columns, do: name
    %{result | columns: columnNames}
  end
  
  def prepare_stream(conn, query_str, params, opts) do
    DBConnection.transaction(
      conn,
      fn conn ->
        query = %Oracle.Query{query_str: query_str}
        stream = DBConnection.prepare_stream(conn, query, params, opts)
        result = Enum.to_list(stream)
        DBConnection.close(conn, query)
        result
      end
    )
  end

  @doc """
  Returns a supervisor child specification for a DBConnection pool.
  """
  def child_spec(opts) do
    DBConnection.child_spec(Oracle.Protocol, opts)
  end

end

defmodule Oracle.EctoAdapter do
  @moduledoc false

  use Ecto.Adapters.SQL,
    driver: :oracle,
    migration_lock: "FOR UPDATE"
end

defmodule Oracle.EctoAdapter.Connection do
  @moduledoc false

  @behaviour Ecto.Adapters.SQL.Connection

  @impl true
  def child_spec(opts) do
    Oracle.child_spec(opts)
  end

  @impl true
  def prepare_execute(conn, name, sql, params, opts) do
    Oracle.prepare_execute(conn, name, sql, params, opts)
  end
end
