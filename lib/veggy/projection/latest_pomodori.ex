defmodule Veggy.Projection.LatestPomodori do
  use Veggy.MongoDB.Projection,
    collection: "projection.latest_pomodori",
    events: ["LoggedIn", "PomodoroStarted", "PomodoroSquashed", "PomodoroCompleted",
             "PomodoroCompletedTracked", "PomodoroSquashedTracked", "PomodoroVoided"],
    identity: "timer_id"

  def process(%{"event" => "LoggedIn"} = event, record) do
    record
    |> Map.put("user_id", event["user_id"])
    |> Map.put("timer_id", event["timer_id"])
    |> Map.put("username", event["username"])
  end
  def process(%{"event" => "PomodoroStarted"} = event, record) do
    record
    |> Map.put("started_at", event["_received_at"])
    |> Map.put("duration", event["duration"])
    |> Map.put("status", "started")
    |> Map.put("_last", record)
    |> Map.delete("completed_at")
    |> Map.delete("squashed_at")
  end
  def process(%{"event" => "PomodoroCompleted"} = event, record) do
    record
    |> Map.put("completed_at", event["_received_at"])
    |> Map.put("status", "completed")
    |> Map.delete("_last")
  end
  def process(%{"event" => "PomodoroSquashed"} = event, record) do
    record
    |> Map.put("squashed_at", event["_received_at"])
    |> Map.put("status", "squashed")
    |> Map.delete("_last")
  end
  def process(%{"event" => "PomodoroCompletedTracked", "started_at" => s1} = event, %{"started_at" => s2} = record) do
    case DateTime.compare(s1, s2) do
      :gt ->
        record
        |> Map.put("started_at", event["started_at"])
        |> Map.put("completed_at", event["completed_at"])
        |> Map.put("duration", event["duration"])
        |> Map.put("status", "completed")
        |> Map.delete("squashed_at")
      _ ->
        :skip
    end
  end
  def process(%{"event" => "PomodoroSquashedTracked", "started_at" => s1} = event, %{"started_at" => s2} = record) do
    case DateTime.compare(s1, s2) do
      :gt ->
        record
        |> Map.put("started_at", event["started_at"])
        |> Map.put("squashed_at", event["squashed_at"])
        |> Map.put("duration", event["duration"])
        |> Map.put("status", "squashed")
        |> Map.delete("completed_at")
      _ ->
        :skip
    end
  end
  def process(%{"event" => "PomodoroVoided"}, %{"_last" => last}) do
    last
  end

  def query("latest-pomodoro", %{"timer_id" => timer_id}) do
    find_one(%{"timer_id" => Veggy.MongoDB.ObjectId.from_string(timer_id),
               "started_at" => %{"$exists" => true}})
  end
  def query("latest-pomodori", _) do
    find(%{})
  end
end
