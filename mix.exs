defmodule HomeRabbit.MixProject do
  use Mix.Project

  def project do
    [
      app: :home_rabbit,
      version: "0.1.0",
      elixir: "~> 1.9",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {HomeRabbit.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:amqp, "~> 1.3.2"},
      {:k_v, github: "PharosProduction/kv"},
    ]
  end
end
