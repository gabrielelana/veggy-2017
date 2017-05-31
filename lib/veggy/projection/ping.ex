defmodule Veggy.Projection.Ping do
  use Veggy.MongoDB.Projection,
    collection: "projection.ping",
    identity: fn(_) -> {:ok, "ping"} end,
    default: %{"counter" => 0},
    events: ["Pong"]

  def process(%{"event" => "Pong"}, %{"counter" => counter} = r),
    do: %{r | "counter" => counter + 1}

  def query("ping", _),
    do: find_one(%{})
end
