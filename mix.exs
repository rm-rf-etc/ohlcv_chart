defmodule OhlcvChart.MixProject do
  use Mix.Project

  def project do
    [
      app: :ohlcv_chart,
      version: "0.1.0",
      elixir: "~> 1.11",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:decimal, "~> 2.0"},
      {:typed_struct, "~> 0.2.1"}
    ]
  end
end
