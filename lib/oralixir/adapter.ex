defmodule OraLixir.EctoAdapter do
  @moduledoc false

  use Ecto.Adapters.SQL, driver: OraLixir, migration_lock: nil

  @behaviour Ecto.Adapter.Storage
  @behaviour Ecto.Adapter.Structure

  @impl true
  def storage_up(_opts), do: err(__ENV__.function)

  @impl true
  def storage_down(_opts), do: err(__ENV__.function)

  @impl true
  def structure_dump(_default, _config), do: err(__ENV__.function)

  @impl true
  def structure_load(_default, _config), do: err(__ENV__.function)

  @impl true
  def supports_ddl_transaction? do
    false
  end

  defp err({op, _}), do: {:error, 'operation #{op} not supported by OraLixir'}

end

defmodule OraLixir.EctoAdapter.Connection do
  @moduledoc false

  @behaviour Ecto.Adapters.SQL.Connection

  @impl true
  def child_spec(opts) do
    DBConnection.child_spec(OraLixir, opts)
  end

  @impl true
  def execute(conn, query, params, opts) do
    DBConnection.execute(conn, query!(query, ""), params, opts)
  end

  @impl true
  def prepare_execute(conn, name, query, params, opts) do
    DBConnection.prepare_execute(conn, query!(query, name), params, opts)
  end

  @impl true
  def stream(conn, query, params, opts) do
    DBConnection.stream(conn, query!(query, ""), params, opts)
  end

  @impl true
  def query(conn, query, params, opts) do
    case DBConnection.prepare_execute(conn, query!(query, ""), params, opts) do
      {:ok, _, result}  -> {:ok, result}
      {:error, err} -> err
    end
  end

  defp query!(sql, name) when is_binary(sql) or is_list(sql) do
    %OraLixir.Query{statement: IO.iodata_to_binary(sql), name: name}
  end
  defp query!(%{} = query, _name) do
    query
  end

  defdelegate all(query), to: OraLixir.Query
  defdelegate update_all(query), to: OraLixir.Query
  defdelegate delete_all(query), to: OraLixir.Query
  defdelegate insert(prefix, table, header, rows, on_conflict, returning), to: OraLixir.Query
  defdelegate update(prefix, table, fields, filters, returning), to: OraLixir.Query
  defdelegate delete(prefix, table, filters, returning), to: OraLixir.Query
  defdelegate table_exists_query(table), to: OraLixir.Query

  @impl true
  def to_constraints(_err), do: []

  @impl true
  def execute_ddl(err), do: error!(err)

  @impl true
  def ddl_logs(err), do: error!(err)

  defp error!(msg) do
    raise DBConnection.ConnectionError, "#{inspect msg}"
  end  

end