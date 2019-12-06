defmodule OraLixir do
  @moduledoc """
  Oracle driver for Elixir.
  """

  @type conn() :: DBConnection.conn()

  @type start_option() ::
          {:hostname, String.t()}
          | {:port, :inet.port_number()}
          | {:service_name, String.t() | nil}
          | {:username, String.t()}
          | {:password, String.t() | nil}
          | {:charset, String.t() | nil}
          | DBConnection.start_option()
  @type option() :: DBConnection.option()

  @doc """
  Starts the connection process and connects to a Oracle server.

  ## Options

    * `:hostname` - Server hostname (default: `"127.0.0.1"`)
    * `:port` - Server port (default: `1521`)
    * `:service_name` - Database (default: `XE`)
    * `:username` - Username (default: `scott`)
    * `:password` - Password (default: `tiger`)
    * `:charset` - A connection charset. On connection handshake, the charset is set to `utf8mb4`,
      but if this option is set, an additional `SET NAMES <charset> [COLLATE <collation>]` query
      will be executed after establishing the connection. `COLLATE` will be added if `:collation`
      is set. (default: `nil`)
   The given options are passed down to DBConnection, some of the most commonly used ones are
   documented below:
    * `:after_connect` - A function to run after the connection has been established, either a
      1-arity fun, a `{module, function, args}` tuple, or `nil` (default: `nil`)
    * `:pool` - The pool module to use (default: `DBConnection.ConnectionPool`)
    * `:pool_size` - The size of the pool
  See `DBConnection.start_link/2` for more information and a full list of available options.

  ## Examples

  Start connection using the default configuration (UNIX domain socket):
      iex> {:ok, pid} = OraLixir.start_link([])
      {:ok, #PID<0.69.0>}

  Start connection using the default configuration (UNIX domain socket):
      iex> OraLixir.prepare_execute(pid, "name", "SELECT 'string', 1, sysdate FROM DUAL", [], [])
      {:ok,
       %OraLixir.Query{
         numCols: 3,
         query_str: "SELECT 'string', 1, sysdate FROM DUAL",
         statement: #Reference<0.4128640180.1299578898.122555>
       },
       %OraLixir.Result{
         columns: [
           %{
             name: '\'STRING\'',
             nullOk: true,
             typeInfo: %{
               clientSizeInBytes: 6,
               dbSizeInBytes: 6,
               defaultNativeTypeNum: :DPI_NATIVE_TYPE_BYTES,
               fsPrecision: 0,
               objectType: :featureNotImplemented,
               ociTypeCode: 96,
               oracleTypeNum: :DPI_ORACLE_TYPE_CHAR,
               precision: 0,
               scale: 0,
               sizeInChars: 6
             }
           },
           %{
             name: '1',
             nullOk: true,
             typeInfo: %{
               clientSizeInBytes: 0,
               dbSizeInBytes: 0,
               defaultNativeTypeNum: :DPI_NATIVE_TYPE_DOUBLE,
               fsPrecision: 0,
               objectType: :featureNotImplemented,
               ociTypeCode: 2,
               oracleTypeNum: :DPI_ORACLE_TYPE_NUMBER,
               precision: 0,
               scale: -127,
               sizeInChars: 0
             }
           },
           %{
             name: 'SYSDATE',
             nullOk: true,
             typeInfo: %{
               clientSizeInBytes: 0,
               dbSizeInBytes: 0,
               defaultNativeTypeNum: :DPI_NATIVE_TYPE_TIMESTAMP,
               fsPrecision: 0,
               objectType: :featureNotImplemented,
               ociTypeCode: 12,
               oracleTypeNum: :DPI_ORACLE_TYPE_DATE,
               precision: 0,
               scale: 0,
               sizeInChars: 0
             }
           }
         ],
         rows: [
           [
             "string",
             1.0,
             %{
               day: 6,
               fsecond: 0,
               hour: 17,
               minute: 57,
               month: 10,
               second: 18,
               tzHourOffset: 0,
               tzMinuteOffset: 0,
               year: 2019
             }
           ]
         ]
       }}

      iex> OraLixir.prepare_stream(pid, "SELECT sysdate, 1, 'first row' FROM DUAL", [], [])
      {:ok,
      [
        [
          %{
            day: 6,
            fsecond: 0,
            hour: 18,
            minute: 4,
            month: 10,
            second: 48,
            tzHourOffset: 0,
            tzMinuteOffset: 0,
            year: 2019
          },
          1.0,
          "first row"
        ],
        :halt
      ]}

  ## Disconnecting on Errors

  Sometimes the connection becomes unusable. For example, some services, such as AWS Aurora,
  support failover. This means the database you are currently connected to may suddenly become
  read-only, and an attempt to do any write operation, such as INSERT/UPDATE/DELETE will lead to
  errors such as:
      ** (MyXQL.Error) (1792) (ER_CANT_EXECUTE_IN_READ_ONLY_TRANSACTION) Cannot execute statement in a READ ONLY transaction.
  Luckily, you can instruct MyXQL to disconnect in such cases by using the following configuration:
      disconnect_on_error_codes: [:ER_CANT_EXECUTE_IN_READ_ONLY_TRANSACTION]
  This cause the connection process to attempt to reconnect according to the backoff configuration.
  MyXQL automatically disconnects the connection on the following error codes and they don't have
  to be configured:
    * `ER_MAX_PREPARED_STMT_COUNT_REACHED`
  To convert error code number to error code name you can use `perror` command-line utility that
  ships with MySQL client installation, e.g.:
      bash$ perror 1792
      MySQL error code 1792 (ER_CANT_EXECUTE_IN_READ_ONLY_TRANSACTION): Cannot execute statement in a READ ONLY transaction.
  """
  @spec start_link([start_option()]) :: {:ok, pid()} | {:error, OraLixir.Error.t()}
  def start_link(opts) do
    DBConnection.start_link(OraLixir.Connection, opts)
  end

  @doc """
  Returns a supervisor child specification for a DBConnection pool.
  """
  @spec child_spec([start_option()]) :: Supervisor.child_spec()
  def child_spec(opts) do
    DBConnection.child_spec(OraLixir.Connection, opts)
  end
  
  def prepare_execute(conn, _name, query_str, params, opts) do
    query = %OraLixir.Query{query_str: query_str}
    result = DBConnection.prepare_execute(conn, query, params, opts)
    DBConnection.close(conn, query)
    result
  end
  
  def prepare_stream(conn, query_str, params, opts) do
    DBConnection.transaction(
      conn,
      fn conn ->
        query = %OraLixir.Query{query_str: query_str}
        stream = DBConnection.prepare_stream(conn, query, params, opts)
        result = Enum.to_list(stream)
        DBConnection.close(conn, query)
        result
      end
    )
  end

  defdelegate checkin(state), to: OraLixir.Connection
  defdelegate checkout(state), to: OraLixir.Connection
  defdelegate connect(opts), to: OraLixir.Connection
  defdelegate disconnect(err, state), to: OraLixir.Connection
  defdelegate handle_begin(opts, state), to: OraLixir.Connection
  defdelegate handle_close(query, opts, state), to: OraLixir.Connection
  defdelegate handle_commit(opts, state), to: OraLixir.Connection
  defdelegate handle_deallocate(query, cursor, opts, state), to: OraLixir.Connection
  defdelegate handle_declare(query, params, opts, state), to: OraLixir.Connection
  defdelegate handle_execute(query, params, opts, state), to: OraLixir.Connection
  defdelegate handle_fetch(query, cursor, opts, state), to: OraLixir.Connection
  defdelegate handle_prepare(query, opts, state), to: OraLixir.Connection
  defdelegate handle_rollback(opts, state), to: OraLixir.Connection
  defdelegate handle_status(opts, state), to: OraLixir.Connection
  defdelegate ping(state), to: OraLixir.Connection

end
