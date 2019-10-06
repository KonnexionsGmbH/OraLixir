defmodule OraLixir.Result do
	@moduledoc """
	Result struct returned from any successful query.

	Its public fields are:

	* `:columns` - The column names;
    * `:rows` - The result set. A list of lists, each inner list corresponding to a
      row, each element in the inner list corresponds to a column

	"""

	@type t :: %__MODULE__{
		columns: [String.t()] | nil,
		rows: [[term()]] | nil
	}

	defstruct [
		:columns, :rows
	]
end
    