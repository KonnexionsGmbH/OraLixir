defmodule OraLixir.Query do
  @moduledoc """
  Query struct returned from a successfully prepared query.

  Its public fields are:

    * `:name` - The name of the prepared statement;
    * `:query_str` - The sql query string;
    * `:num_cols` - The number of columns returned by the query;
    * `:statement` - The prepared statement
    * `:info` - Meta information about the statement
  
  ## Named and Unnamed Queries (TBD)

  Named queries are identified by the non-empty value in `:name` field
  and are meant to be re-used.
  Unnamed queries, with `:name` equal to `""`, are automatically closed
  after being executed.
  """

  defstruct [
    :query_str,
    :statement,
    :numCols,
    :info
  ]

  defimpl DBConnection.Query do
    def parse(query, _opts), do: query
    def describe(query, _opts), do: query
    def encode(_query, params, _opts), do: params
    def decode(_query, result, _opts), do: result
  end

end