defmodule ExampleProject.MixProject do
  use Mix.Project

  def project do
    [
      app: :example_project,
      # Prepend remote compiler to the default list
      compilers: [:remote] ++ Mix.compilers(),
      version: "0.1.0",
      elixir: "~> 1.14",
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
      {:remote, path: "../"}
    ]
  end
end
