defmodule TogglerCli.MixProject do
  use Mix.Project

  def project do
    [
      app: :toggler_cli,
      version: "0.1.0",
      elixir: "~> 1.11",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      escript: [main_module: TogglerCli.App]
      # TODO how do i make this work with escript?
      # releases: [
      #   toggler_cli: [
      #     version: "1.0.0",
      #     config_providers: [
      #       {TomlConfigProvider, path: "config.toml"}
      #     ]
      #   ]
      # ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      toggler_cli: []
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:jason, "~> 1.0"},
      {:httpoison, "~> 1.7"},
      {:poison, "~> 3.1"},
      # doesn't work with escript!
      # {:tzdata, "~> 1.0.4"},
      {:floki, "~> 0.29.0"},
      {:decimal, "~> 2.0"}
      # {:toml_config, "~> 0.1.0"}
      # static analysis
      # {:credo, "~> 1.5", only: [:dev, :test], runtime: false}
    ]
  end
end
