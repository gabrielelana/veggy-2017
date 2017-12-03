defmodule Veggy.Aggregate.Timer do
  use Veggy.Aggregate
  use Veggy.MongoDB.Aggregate, collection: "aggregate.timers"

  @default_duration 1_500_000   # 25 minutes in milliseconds

  defp aggregate_id(%{"timer_id" => timer_id}) when is_binary(timer_id),
    do: Veggy.MongoDB.ObjectId.from_string(timer_id)
  defp aggregate_id(%{"timer_id" => timer_id}),
    do: timer_id

  def route(%{"command" => "StartPomodoro"} = p) do
    {:ok, command("StartPomodoro", aggregate_id(p),
        duration: Map.get(p, "duration", @default_duration),
        description: Map.get(p, "description", ""))}
  end
  def route(%{"command" => "CompletePomodoro"} = p) do
    {:ok, command("CompletePomodoro", aggregate_id(p),
        [])}
  end
  def route(%{"command" => "SquashPomodoro"} = p) do
    {:ok, command("SquashPomodoro", aggregate_id(p),
        reason: Map.get(p, "reason", ""))}
  end

  def init(id) do
    {:ok, %{"id" => id, "ticking" => false}}
  end

  def handle(%{"command" => "CreateTimer", "user_id" => user_id}, _) do
    {:ok, event("TimerCreated", user_id: user_id)}
  end
  def handle(%{"command" => "StartPomodoro"}, %{"ticking" => true}), do: {:error, "Pomodoro is ticking"}
  def handle(%{"command" => "StartPomodoro"} = c, s) do
    {:ok, pomodoro_id} = Veggy.Countdown.start(c["duration"], s["id"])
    {:ok, event("PomodoroStarted",
        pomodoro_id: pomodoro_id,
        duration: c["duration"],
        description: c["description"])}
  end
  def handle(%{"command" => "CompletePomodoro"}, %{"ticking" => false}), do: {:error, "Pomodoro is not ticking"}
  def handle(%{"command" => "CompletePomodoro"}, _) do
    {:ok, event("PomodoroCompleted", [])}
  end
  def handle(%{"command" => "SquashPomodoro"}, %{"ticking" => false}), do: {:error, "Pomodoro is not ticking"}
  def handle(%{"command" => "SquashPomodoro"} = c, %{"pomodoro_id" => pomodoro_id}) do
    :ok = Veggy.Countdown.squash(pomodoro_id)
    {:ok, event("PomodoroSquashed",
        reason: c["reason"])}
  end

  def process(%{"event" => "TimerCreated", "user_id" => user_id}, s),
    do: Map.put(s, "user_id", user_id)

  def process(%{"event" => "PomodoroStarted", "pomodoro_id" => pomodoro_id}, s),
    do: %{s | "ticking" => true} |> Map.put("pomodoro_id", pomodoro_id)

  def process(%{"event" => "PomodoroSquashed"}, s),
    do: %{s | "ticking" => false} |> Map.delete("pomodoro_id")

  def process(%{"event" => "PomodoroCompleted"}, s),
    do: %{s | "ticking" => false} |> Map.delete("pomodoro_id")
end
