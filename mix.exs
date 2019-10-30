defmodule OraLixir.MixProject do
  use Mix.Project

  def project do
    [
      app: :oralixir,
      version: "0.1.0",
      elixir: "~> 1.9",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:ecto_sql, "~> 3.0"},
      {
        :oranif,
        git: "https://github.com/c-bik/oranif.git",
        tag: "cruz-elixir-comments"
      }
    ]
  end
end
