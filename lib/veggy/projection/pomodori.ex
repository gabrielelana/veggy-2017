defmodule Veggy.Projection.Pomodori do
  use Veggy.MongoDB.Projection,
    collection: "projection.pomodori",
    events: ["PomodoroStarted", "PomodoroSquashed", "PomodoroCompleted",
             "PomodoroCompletedTracked", "PomodoroSquashedTracked", "PomodoroVoided"],
    identity: "pomodoro_id"

  def process(%{"event" => "PomodoroStarted"} = event, record) do
    record
    |> Map.put("pomodoro_id", event["pomodoro_id"])
    |> Map.put("timer_id", event["aggregate_id"])
    |> Map.put("started_at", event["_received_at"])
    |> Map.put("status", "started")
    |> Map.put("description", event["description"])
    |> Map.put("tags", event["tags"])
    |> Map.put("shared_with", event["shared_with"])
    |> Map.put("duration", event["duration"])
  end
  def process(%{"event" => "PomodoroCompleted"} = event, record) do
    record
    |> Map.put("completed_at", event["_received_at"])
    |> Map.put("status", "completed")
  end
  def process(%{"event" => "PomodoroSquashed"} = event, record) do
    record
    |> Map.put("squashed_at", event["_received_at"])
    |> Map.put("status", "squashed")
  end
  def process(%{"event" => "PomodoroCompletedTracked"} = event, record) do
    record
    |> Map.put("pomodoro_id", event["pomodoro_id"])
    |> Map.put("timer_id", event["aggregate_id"])
    |> Map.put("started_at", event["started_at"])
    |> Map.put("tags", event["tags"])
    |> Map.put("shared_with", [])
    |> Map.put("duration", event["duration"])
    |> Map.put("description", event["description"])
    |> Map.put("completed_at", event["completed_at"])
    |> Map.put("status", "completed")
  end
  def process(%{"event" => "PomodoroSquashedTracked"} = event, record) do
    record
    |> Map.put("pomodoro_id", event["pomodoro_id"])
    |> Map.put("timer_id", event["aggregate_id"])
    |> Map.put("started_at", event["started_at"])
    |> Map.put("tags", event["tags"])
    |> Map.put("shared_with", [])
    |> Map.put("duration", event["duration"])
    |> Map.put("description", event["description"])
    |> Map.put("squashed_at", event["squashed_at"])
    |> Map.put("status", "squashed")
  end
  def process(%{"event" => "PomodoroVoided"}, _) do
    :delete
  end

  def query("tags-of-the-day", %{"day" => day, "timer_id" => timer_id}) do
    timer_id = Veggy.MongoDB.ObjectId.from_string(timer_id)
    case Veggy.MongoDB.DateTime.in_day(day) do
      {:ok, beginning_of_day, end_of_day} ->
        {:ok, pomodori} = find(%{"started_at" => %{"$gte" => beginning_of_day, "$lte" => end_of_day},
                                 "timer_id" => timer_id,
                                })

        {:ok, pomodori
        |> Enum.filter(fn(p) -> Map.has_key?(p, "completed_at") end)
        |> Enum.map(&Map.take(&1, ["tags", "duration"]))
        |> Enum.flat_map(fn(p) -> for tag <- p["tags"], do: %{"tag" => tag, "pomodori" => 1, "duration" => p["duration"]} end)
        |> Enum.group_by(&Map.get(&1, "tag"))
        |> Map.values()
        |> Enum.map(&Enum.reduce(&1, fn(p, a) -> %{a|"pomodori" => a["pomodori"] + 1, "duration" => a["duration"] + p["duration"]} end))
        }
      {:error, reason} ->
        {:error, reason}
    end
  end

  def query("pomodori-of-the-day", %{"day" => day, "timer_id" => timer_id}) do
    timer_id = Veggy.MongoDB.ObjectId.from_string(timer_id)
    case Veggy.MongoDB.DateTime.in_day(day) do
      {:ok, beginning_of_day, end_of_day} ->
        find(%{"started_at" => %{"$gte" => beginning_of_day, "$lte" => end_of_day},
               "timer_id" => timer_id,
              })
      {:error, reason} ->
        {:error, reason}
    end
  end
end
