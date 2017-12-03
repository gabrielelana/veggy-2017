defmodule Veggy.Aggregate.Timer do
  @default_duration 1_500_000   # 25 minutes in milliseconds

  def route(p = %{"command" => "StartPomodoro"}) do
    {:ok, %{"command" => "StartPomodoro",
            "aggregate_id" => "timer",
            "aggregate_module" => __MODULE__,
            "duration" => Map.get(p, "duration", @default_duration),
            "description" => Map.get(p, "description", ""),
            "_id" => Veggy.UUID.new}}
  end
  def route(p = %{"command" => "CompletePomodoro"}) do
    {:ok, %{"command" => "CompletePomodoro",
            "aggregate_id" => "timer",
            "aggregate_module" => __MODULE__,
            "pomodoro_id" => Map.get(p, "pomodoro_id"),
            "_id" => Veggy.UUID.new}}
  end

  def init(id) do
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
  def handle(c = %{"command" => "StartPomodoro"}, s) do
    {:ok, pomodoro_id} = Veggy.Countdown.start(c["duration"], s["id"])
    {:ok, %{"event" => "PomodoroStarted",
            "command_id" => c["_id"],
            "aggregate_id" => s["id"],
            "pomodoro_id" => pomodoro_id,
            "duration" => c["duration"],
            "description" => c["description"],
            "_id" => Veggy.UUID.new}}
  end

  def handle(%{"command" => "CompletePomodoro"}, %{"ticking" => false}), do: {:error, "Pomodoro is not ticking"}
  def handle(c = %{"command" => "CompletePomodoro"}, s) do
    {:ok, %{"event" => "PomodoroCompleted",
            "command_id" => c["_id"],
            "aggregate_id" => s["id"],
            "pomodoro_id" => c["pomodoro_id"],
            "_id" => Veggy.UUID.new}}
  end

  def process(%{"event" => "PomodoroStarted"}, s), do: %{s | "ticking" => true}
  def process(%{"event" => "PomodoroCompleted"}, s), do: %{s | "ticking" => false}
end
