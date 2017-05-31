defmodule Veggy do
  use Application
  import Supervisor.Spec, warn: false

  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do

    # Define workers and child supervisors to be supervised
    children = [
      Veggy.MongoDB.child_spec,
      worker(Veggy.EventStore, []),
      worker(Veggy.Countdown, []),
      aggregates(),
      projections(),
      Plug.Adapters.Cowboy.child_spec(:http, Veggy.HTTP, [],
        [port: 4000, dispatch: dispatch()]),
    ] |> Enum.reject(&is_nil/1)

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Veggy.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp aggregates do
    if Application.get_env(:veggy, :enable_aggregates, true),
      do: worker(Veggy.Aggregates, [[Veggy.Aggregate.Ping,
                                     Veggy.Aggregate.Timer,
                                     Veggy.Aggregate.User]]),
      else: nil
  end

  defp projections do
    if Application.get_env(:veggy, :enable_projections, true),
      do: worker(Veggy.Projections, [[Veggy.Projection.Commands,
                                      Veggy.Projection.Ping,
                                      Veggy.Projection.LatestPomodori]]),
      else: nil
  end

  defp dispatch do
    websocket = {"/ws", Veggy.WS, []}
    otherwise = {:_, Plug.Adapters.Cowboy.Handler, {Veggy.HTTP, []}}
    [{:_, [websocket, otherwise]}]
  end
end
