defmodule Oracle do
  @moduledoc """
  Adapter module for Oracle. `DBConnection` behaviour implementation.

  It uses `oranif` for communicating to the database.

  opts = [
    connectString: "(DESCRIPTION=(ADDRESS_LIST=(ADDRESS=(PROTOCOL=TCP)(HOST=127.0.0.1)(PORT=1521)))(CONNECT_DATA=(SERVER=dedicated)(SERVICE_NAME=XE)))",
    userName: "scott",
    password: "regit",
  ]
  DBConnection.start_link(Oracle, opts)
  state = Oracle.connect(opts)
  :ok = Oracle.disconnect(:ok, state)
  """

  # DPI_MAJOR_VERSION and DPI_MINOR_VERSION
  # define https://github.com/oracle/odpi/blob/v3.0.0/include/dpi.h#L46-L47

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

  def start_link(opts) do
    DBConnection.start_link(Oracle, opts)
  end
  
  @impl true
  def connect(opts) do
    true = Keyword.has_key?(opts, :connectString)
    true = Keyword.has_key?(opts, :userName)
    true = Keyword.has_key?(opts, :password)

    ora = %Oracle{}
  
    case Keyword.fetch(opts, :slave) do
      {:ok, slave} -> :dpi.load slave
      :error -> :dpi.load_unsafe
    end
    |>
    case do
      :ok ->
        create_context_connection ora, opts
      slave when is_atom(slave) ->
        create_context_connection %{ora | oranifNode: slave}, opts
      error ->
        {:error, error}
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

  defp create_context_connection(ora, opts) do
    connectString = Keyword.fetch!(opts, :connectString)
    userName = Keyword.fetch!(opts, :userName)
    password = Keyword.fetch!(opts, :password)
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
          [context, userName, password, connectString, commonParams, createParams]
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

end
