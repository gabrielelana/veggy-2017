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
        shared_with: Map.get(p, "shared_with", []) |> Enum.map(&Veggy.MongoDB.ObjectId.from_string/1),
        description: Map.get(p, "description", ""))}
  end
  def route(%{"command" => "StartSharedPomodoro"} = p) do
    {:ok, command("StartSharedPomodoro", aggregate_id(p),
        duration: Map.get(p, "duration", @default_duration),
        shared_with: Map.get(p, "shared_with", []) |> Enum.map(&Veggy.MongoDB.ObjectId.from_string/1),
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
  def route(%{"command" => "SquashSharedPomodoro"} = p) do
    {:ok, command("SquashSharedPomodoro", aggregate_id(p),
        reason: Map.get(p, "reason", ""))}
  end

  def init(id) do
    {:ok, %{"id" => id, "ticking" => false}}
  end

  def check(%{"ticking" => true, "pomodoro_id" => pomodoro_id} = s) do
    {:ok, s, [event("PomodoroVoided", pomodoro_id: pomodoro_id, reason: "Inconsistent state at startup")]}
  end
  def check(s) do
    {:ok, s}
  end

  def handle(%{"command" => "CreateTimer", "user_id" => user_id}, _) do
    {:ok, event("TimerCreated", user_id: user_id)}
  end
  def handle(%{"command" => "StartPomodoro"}, %{"ticking" => true}), do: {:error, "Pomodoro is ticking"}
  def handle(%{"command" => "StartPomodoro"} = c, s) do
    {:ok, pomodoro_id} = Veggy.Countdown.start(c["duration"], s["id"])
    {:ok, event("PomodoroStarted",
        pomodoro_id: pomodoro_id,
        shared_with: c["shared_with"],
        duration: c["duration"],
        shared_with: c["shared_with"],
        description: c["description"])}
  end
  def handle(%{"command" => "CompletePomodoro"}, %{"ticking" => false}), do: {:error, "Pomodoro is not ticking"}
  def handle(%{"command" => "CompletePomodoro"}, _) do
    {:ok, event("PomodoroCompleted", [])}
  end
  def handle(%{"command" => "SquashPomodoro"}, %{"ticking" => false}), do: {:error, "Pomodoro is not ticking"}
  def handle(%{"command" => "SquashPomodoro"} = c, %{"pomodoro_id" => pomodoro_id}) do
    :ok = Veggy.Countdown.squash(pomodoro_id)
    {:ok, event("PomodoroSquashed", reason: c["reason"])}
  end
  def handle(%{"command" => "SquashSharedPomodoro"} = c, %{"shared_with" => shared_with} = s) do
    pair = [s["id"] | shared_with]
    commands = Enum.map(pair, fn(id) ->
      command("SquashPomodoro", id,
        reason: c["reason"])
    end)
    {:ok, [], {:fork, commands}}
  end
  def handle(%{"command" => "StartSharedPomodoro", "shared_with" => shared_with} = c, s) do
    pair = [s["id"] | shared_with]
    commands = Enum.map(pair, fn(id) ->
      command("StartPomodoro", id,
        duration: c["duration"],
        shared_with: pair -- [id],
        description: c["description"])
    end)
    {:ok, [], {:fork, commands}}
  end
  def handle(%{"command" => "SquashSharedPomodoro"} = c, %{"shared_with" => shared_with} = s) do
    pair = [s["id"] | shared_with]
    commands = Enum.map(pair, fn(id) ->
      command("SquashPomodoro", id,
        reason: c["reason"])
    end)
    {:ok, [], commands}
  end

  def rollback(%{"command" => "StartPomodoro"}, %{"ticking" => false}), do: {:error, "No pomodoro to rollback"}
  def rollback(%{"command" => "StartPomodoro"}, %{"pomodoro_id" => pomodoro_id}) do
    :ok = Veggy.Countdown.void(pomodoro_id)
    {:ok, event("PomodoroVoided", [])}
  end

  def process(%{"event" => "TimerCreated", "user_id" => user_id}, s) do
    Map.put(s, "user_id", user_id)
  end
  def process(%{"event" => "PomodoroStarted"} = e, s) do
    %{s | "ticking" => true}
    |> Map.put("pomodoro_id", e["pomodoro_id"])
    |> Map.put("shared_with", e["shared_with"])
  end
  def process(%{"event" => "PomodoroSquashed"}, s) do
    %{s | "ticking" => false}
    |> Map.delete("pomodoro_id")
    |> Map.delete("shared_with")
  end
  def process(%{"event" => "PomodoroCompleted"}, s) do
    %{s | "ticking" => false}
    |> Map.delete("pomodoro_id")
    |> Map.delete("shared_with")
  end
  def process(%{"event" => "PomodoroVoided"}, s) do
    %{s | "ticking" => false}
    |> Map.delete("pomodoro_id")
    |> Map.delete("shared_with")
  end
end
