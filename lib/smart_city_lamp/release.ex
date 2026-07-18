defmodule SmartCityLamp.Release do
  @moduledoc false

  @app :smart_city_lamp

  def setup do
    migrate()

    if enabled?(System.get_env("INIT_DEMO_DATA", "false")) do
      seed_demo()
    end
  end

  def migrate do
    load_app()

    for repo <- Application.fetch_env!(@app, :ecto_repos) do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end
  end

  def rollback(repo, version) do
    load_app()
    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
  end

  def seed_demo do
    load_app()
    seeds = Application.app_dir(@app, "priv/repo/seeds.exs")

    for repo <- Application.fetch_env!(@app, :ecto_repos) do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, fn _repo -> Code.eval_file(seeds) end)
    end

    :ok
  end

  defp load_app do
    Application.load(@app)
  end

  defp enabled?(value), do: String.downcase(value) in ~w(true 1 yes on)
end
