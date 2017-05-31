defmodule Veggy.Aggregate.Ping do
  def route(%{"command" => "Ping"}) do
    {:ok, %{"command" => "Ping",
            "aggregate_id" => "ping",
            "aggregate_module" => __MODULE__,
            "_id" => Veggy.UUID.new}}
  end

  def init(id), do: {:ok, %{"id" => id, "counter" => 1}}

  def fetch(_id, s), do: {:ok, s}

  def store(_s), do: :ok

  def check(s), do: {:ok, s}

  def handle(%{"command" => "Ping"} = c, s) do
    {:ok, %{"event" => "Pong",
            "counter" => s["counter"],
            "aggregate_id" => s["id"],
            "command_id" => c["_id"],
            "_id" => Veggy.UUID.new}}
  end

  def process(%{"event" => "Pong"}, %{"counter" => counter} = s),
    do: %{s | "counter" => counter + 1}
end
