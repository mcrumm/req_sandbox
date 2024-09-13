defmodule ReqSandbox.MixProject do
  use Mix.Project

  @source_url "https://github.com/mcrumm/req_sandbox"

  @version "0.1.2"

  def project do
    [
      app: :req_sandbox,
      version: @version,
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: docs(),
      package: package(),
      aliases: [
        "test.all": ["test --include integration"]
      ],
      preferred_cli_env: [
        "test.all": :test
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
      {:req, "~> 0.4.0 or ~> 0.5.0"},

      # Dev/Test dependencies
      {:phoenix_ecto, "~> 4.0", only: :test},
      {:ecto_sql, "~> 3.9.0", only: :test},
      {:postgrex, "~> 0.16", only: :test},
      {:ex_doc, "> 0.0.0", only: :dev}
    ]
  end

  defp docs do
    [
      source_url: @source_url,
      source_ref: "v#{@version}",
      language: "en",
      formatters: ["html"],
      main: "ReqSandbox",
      extras: ["CHANGELOG.md", "guides/usage.livemd"],
      groups_for_extras: [Guides: ~r/^guides/]
    ]
  end

  defp package do
    [
      description: "ReqSandbox simplifies concurrent, transactional tests for external clients.",
      maintainers: ["Michael A. Crumm Jr."],
      licenses: ["MIT"],
      links: %{
        "GitHub" => "https://github.com/mcrumm/req_sandbox",
        "Sponsor" => "https://github.com/sponsors/mcrumm"
      }
    ]
  end
end
