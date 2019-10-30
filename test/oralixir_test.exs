defmodule OraLixirTest do
  use ExUnit.Case
  #doctest OraLixir
  @connect_opts [password: "tiger"]

  test "select dual" do    
    {:ok, pid} = OraLixir.start_link(@connect_opts)
    assert is_pid(pid) == true
    queryStr = "SELECT 'some string' as col_string, 1 as col_number FROM DUAL"
    {
      :ok,
      %OraLixir.Query{info: info, numCols: 2, query_str: query_str},
      %OraLixir.Result{columns: columns, rows: rows}
    } = OraLixir.prepare_execute(pid, "dual", queryStr, [], [])
    assert info == %{
      :isDDL => false, :isDML => false, :isPLSQL => false, :isQuery => true,
      :isReturning => false, :statementType => :DPI_STMT_TYPE_SELECT
    }
    assert query_str == queryStr
    assert is_list(columns) == true
    assert ['COL_NUMBER', 'COL_STRING'] == Enum.sort(
      for %{:name => name} <- columns, do: name
    )
    assert [["some string", 1.0]] == Enum.sort(rows)
  end

  test "drop create insert update select truncate" do
    {:ok, pid} = OraLixir.start_link(@connect_opts)
    assert is_pid(pid) == true
    dropSql = "DROP TABLE OraLixir_test"
    case OraLixir.prepare_execute(pid, "drop", dropSql, [], []) do
      {:error, %OraLixir.Error{details: %{:reason => %{code: 942}}}} -> :ok
      {
        :ok,
        %OraLixir.Query{
          info: %{
            :isDDL => true, :isDML => false, :isPLSQL => false,
            :isQuery => false, :isReturning => false,
            :statementType => :DPI_STMT_TYPE_DROP
          },
          numCols: 0,
          query_str: query_str
        },
        :ok
      } ->
        assert dropSql == query_str        
    end
    IO.puts("Table OraLixir_test dropped if existed")

    createSql = "CREATE TABLE OraLixir_test (COL1 NUMBER, COL2 VARCHAR2(1000))"
    {
      :ok,
      %OraLixir.Query{
        info: %{
          :isDDL => true, :isDML => false, :isPLSQL => false,
          :isQuery => false, :isReturning => false,
          :statementType => :DPI_STMT_TYPE_CREATE
        },
        numCols: 0,
        query_str: query_str
      },
      :ok
    } = OraLixir.prepare_execute(pid, "dual", createSql, [], [])
    assert createSql == query_str
    IO.puts("Table OraLixir_test created : #{createSql}")

    insertSql = "INSERT INTO OraLixir_test (COL1, COL2) VALUES(1, 'one')"
    {
      :ok,
      %OraLixir.Query{
        info: %{
          :isDDL => false, :isDML => true, :isPLSQL => false,
          :isQuery => false, :isReturning => false,
          :statementType => :DPI_STMT_TYPE_INSERT
        },
        numCols: 0,
        query_str: query_str
      },
      :ok
    } = OraLixir.prepare_execute(pid, "insert-1", insertSql, [], [])
    assert insertSql == query_str
    IO.puts("First row inserted to OraLixir_test : #{insertSql}")

    insertSql = "INSERT INTO OraLixir_test (COL1, COL2) VALUES(2, 'two')"
    {
      :ok,
      %OraLixir.Query{
        info: %{
          :isDDL => false, :isDML => true, :isPLSQL => false,
          :isQuery => false, :isReturning => false,
          :statementType => :DPI_STMT_TYPE_INSERT
        },
        numCols: 0,
        query_str: query_str
      },
      :ok
    } = OraLixir.prepare_execute(pid, "insert-2", insertSql, [], [])
    assert insertSql == query_str
    IO.puts("Second row inserted to OraLixir_test : #{insertSql}")

    selectSql = "SELECT * FROM OraLixir_test"
    {
      :ok,
      %OraLixir.Query{
        info: %{
          :isDDL => false, :isDML => false, :isPLSQL => false,
          :isQuery => true, :isReturning => false,
          :statementType => :DPI_STMT_TYPE_SELECT
        },
        numCols: 2,
        query_str: query_str
      },
      %OraLixir.Result{
        columns: columns,
        rows: rows
      }
    } = OraLixir.prepare_execute(pid, "select", selectSql, [], [])
    assert selectSql == query_str
    assert is_list(columns) == true
    assert ['COL1', 'COL2'] == Enum.sort(
      for %{:name => name} <- columns, do: name
    )
    assert [[1.0, "one"], [2.0, "two"]] == Enum.sort(rows)
    IO.puts("All rows selected from OraLixir_test : #{selectSql}")

    updateSql = "UPDATE OraLixir_test SET COL1=3, COL2='three' WHERE COL1=2"
    {
      :ok,
      %OraLixir.Query{
        info: %{
          :isDDL => false, :isDML => true, :isPLSQL => false,
          :isQuery => false, :isReturning => false,
          :statementType => :DPI_STMT_TYPE_UPDATE
        },
        numCols: 0,
        query_str: query_str
      },
      :ok
    } = OraLixir.prepare_execute(pid, "updtae", updateSql, [], [])
    assert updateSql == query_str
    IO.puts("Updated one row in OraLixir_test : #{updateSql}")

    {
      :ok,
      %OraLixir.Query{
        info: %{
          :isDDL => false, :isDML => false, :isPLSQL => false,
          :isQuery => true, :isReturning => false,
          :statementType => :DPI_STMT_TYPE_SELECT
        },
        numCols: 2,
        query_str: _
      },
      %OraLixir.Result{
        columns: _,
        rows: rows
      }
    } = OraLixir.prepare_execute(pid, "select", selectSql, [], [])
    assert [[1.0, "one"], [3.0, "three"]] == Enum.sort(rows)
    IO.puts(
      "All rows selected from OraLixir_test (including updated) : #{selectSql}"
    )

    truncateSql = "TRUNCATE TABLE OraLixir_test"
    {
      :ok,
      %OraLixir.Query{
        info: %{
          :isDDL => false, :isDML => false, :isPLSQL => false,
          :isQuery => false, :isReturning => false,
          :statementType => :DPI_STMT_TYPE_UNKNOWN
        },
        numCols: 0,
        query_str: query_str
      },
      :ok
    } = OraLixir.prepare_execute(pid, "truncate", truncateSql, [], [])
    assert truncateSql == query_str
    IO.puts("truncated all rows from OraLixir_test : #{updateSql}")

    {
      :ok,
      %OraLixir.Query{
        info: %{
          :isDDL => false, :isDML => false, :isPLSQL => false,
          :isQuery => true, :isReturning => false,
          :statementType => :DPI_STMT_TYPE_SELECT
        },
        numCols: 2,
        query_str: _
      },
      %OraLixir.Result{
        columns: _,
        rows: rows
      }
    } = OraLixir.prepare_execute(pid, "select", selectSql, [], [])
    assert [] == rows
    IO.puts(
      "No rows selected from OraLixir_test (after truncate) : #{selectSql}"
    )

  end

end
