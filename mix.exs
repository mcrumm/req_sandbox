defmodule ReqSandbox.MixProject do
  use Mix.Project

  @source_url "https://github.com/mcrumm/req_sandbox"

  @version "0.1.0"

  def project do
    [
      app: :req_sandbox,
      version: @version,
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: docs()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:req, "~> 0.3.0"},
      {:plug, "~> 1.0", only: :test},
      {:ex_doc, "> 0.0.0", only: :dev}
    ]
  end

  defp docs do
    [
      source_url: @source_url,
      source_ref: "v#{@version}",
      deps: [],
      language: "en",
      formatters: ["html"],
      main: "ReqSandbox",
      extras: ["CHANGELOG.md"]
    ]
  end
end
