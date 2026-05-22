defmodule LexCredo.MixProject do
  use Mix.Project

  def project do
    [
      app: :lex_credo,
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),

      # ExDoc
      name: "LexCredo",
      source_url: "https://github.com/sippy-platform/lex_credo",
      docs: docs(),

      # ExCoveralls
      test_coverage: [tool: ExCoveralls]
    ]
  end

  def cli do
    [
      preferred_envs: [
        precommit: :test,
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.html": :test,
        "coveralls.json": :test
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:credo, "~> 1.7"},

      # Documentation
      {:ex_doc, "~> 0.31", only: :dev, runtime: false},

      # Testing
      {:excoveralls, "~> 0.18", only: :test, runtime: false}
    ]
  end

  defp aliases do
    [
      precommit: ["compile", "format", "credo --all", "test"]
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md", "CHANGELOG.md", "LICENSE"],
      groups_for_modules: [
        "Checks – Design": ~r/LexCredo\.Check\.Design/,
        "Checks – Readability": ~r/LexCredo\.Check\.Readability/,
        "Checks – Refactor": ~r/LexCredo\.Check\.Refactor/,
        "Checks – Warning": ~r/LexCredo\.Check\.Warning/
      ]
    ]
  end
end
