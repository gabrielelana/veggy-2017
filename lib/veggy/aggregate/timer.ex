defmodule Veggy.Aggregate.Timer do
  @default_duration 1_500_000   # 25 minutes in milliseconds

  def route(%{"command" => "StartPomodoro"} = params) do
    {:ok, %{"command" => "StartPomodoro",
            "aggregate_id" => "timer",
            "aggregate_module" => __MODULE__,
            "duration" => Map.get(params, "duration", @default_duration),
            "description" => Map.get(params, "description", ""),
            "_id" => Veggy.UUID.new}}
  end
  def route(%{"command" => "SquashPomodoro"} = params) do
    {:ok, %{"command" => "SquashPomodoro",
            "aggregate_id" => "timer",
            "aggregate_module" => __MODULE__,
            "reason" => Map.get(params, "reason", ""),
            "_id" => Veggy.UUID.new}}
  end


  def init(id) do
    Veggy.EventStore.subscribe(self(), &match?(%{"event" => "PomodoroCompleted", "aggregate_id" => ^id}, &1))
    {:ok, %{"id" => id, "ticking" => false}}
  end

  def fetch(id, s) do
    case Mongo.find(Veggy.MongoDB, "aggregate.timers", %{"_id" => id}) |> Enum.to_list do
      [d] -> {:ok, d |> Map.put("id", d["_id"]) |> Map.delete("_id") |> Veggy.MongoDB.from_document}
      _ -> {:ok, s}
    end
  end

  def store(s) do
    s = s |> Map.put("_id", s["id"]) |> Map.delete("id") |> Veggy.MongoDB.to_document
    {:ok, _} = Mongo.save_one(Veggy.MongoDB, "aggregate.timers", s)
  end

  def check(s) do
    {:ok, s}
  end

  def handle(%{"command" => "StartPomodoro"}, %{"ticking" => true}), do: {:error, "Pomodoro is ticking"}
  def handle(%{"command" => "StartPomodoro"} = c, s) do
    {:ok, pomodoro_id} = Veggy.Countdown.start(c["duration"], s["id"], c["_id"])
    {:ok, %{"event" => "PomodoroStarted",
            "pomodoro_id" => pomodoro_id,
            "user_id" => s["user_id"],
            "command_id" => c["_id"],
            "aggregate_id" => s["id"],
            "timer_id" => s["id"],
            "duration" => c["duration"],
            "description" => c["description"],
            "_id" => Veggy.UUID.new}}
  end
  def handle(%{"command" => "SquashPomodoro"}, %{"ticking" => false}), do: {:error, "Pomodoro is not ticking"}
  def handle(%{"command" => "SquashPomodoro"} = c, %{"pomodoro_id" => pomodoro_id} = s) do
    :ok = Veggy.Countdown.squash(pomodoro_id)
    {:ok, %{"event" => "PomodoroSquashed",
            "pomodoro_id" => pomodoro_id,
            "user_id" => s["user_id"],
            "command_id" => c["_id"],
            "aggregate_id" => s["id"],
            "timer_id" => s["id"],
            "reason" => c["reason"],
            "_id" => Veggy.UUID.new}}
  end

  def process(%{"event" => "PomodoroStarted", "pomodoro_id" => pomodoro_id}, s),
    do: %{s | "ticking" => true} |> Map.put("pomodoro_id", pomodoro_id)
  def process(%{"event" => "PomodoroSquashed"}, s),
    do: %{s | "ticking" => false} |> Map.delete("pomodoro_id")
  def process(%{"event" => "PomodoroCompleted"}, s),
    do: %{s | "ticking" => false} |> Map.delete("pomodoro_id")
end
