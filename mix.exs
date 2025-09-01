defmodule Remote.MixProject do
  use Mix.Project

  def project do
    [
      app: :remote,
      description: "Compile project remotely and sync back build artifacts.",
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: docs(),
      package: package(),
      dialyzer: [plt_add_apps: [:mix]]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp docs do
    [
      source_ref: "v#{@version}",
      main: "readme",
      source_url: "https://github.com/dariodf/remote",
      extras: ["README.md"]
    ]
  end

  defp package do
    [
      files: ~w(lib test mix.exs README.md LICENSE),
      maintainers: ["dariodf"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/dariodf/remote"}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev], runtime: false},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false},
      {:mox, "~> 1.0", only: :test}
    ]
  end
end
