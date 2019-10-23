# OraLixir

An [ecto](https://github.com/elixir-ecto/ecto) adapter for Oracle using [oranif](https://github.com/c-bik/oranif/).

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `oracle` to your list of dependencies in `mix.exs`:

```elixir
defp deps do
  [
    {:oralixir, git: "https://github.com/c-bik/OraLixir"}}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/oralixir](https://hexdocs.pm/oralixir).

## Examples

  Start connection using the default configuration (UNIX domain socket):
```elixir
iex> {:ok, pid} = OraLixir.start_link([])
{:ok, #PID<0.69.0>}
```

  Start connection using the default configuration (UNIX domain socket):
```elixir
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
```
