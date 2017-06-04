defmodule Veggy.Projection.Pomodori do
  use Testable
  use Veggy.MongoDB.Projection,
    collection: "projection.pomodori",
    events: ["PomodoroStarted", "PomodoroSquashed", "PomodoroCompleted",
             "PomodoroVoided"],
    identity: "pomodoro_id"

  def process(%{"event" => "PomodoroStarted"} = event, record) do
    record
    |> Map.put("pomodoro_id", event["pomodoro_id"])
    |> Map.put("timer_id", event["aggregate_id"])
    |> Map.put("started_at", event["_received_at"])
    |> Map.put("status", "started")
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
  def process(%{"event" => "PomodoroVoided"}, _) do
    :delete
  end

  def query("pomodori-of-the-day", %{"day" => day, "timer_id" => timer_id}) do
    timer_id = Veggy.MongoDB.ObjectId.from_string(timer_id)
    case Veggy.MongoDB.DateTime.in_day(day) do
      {:ok, beginning_of_day, end_of_day} ->
        with {:ok, pomodori} <- find(%{"started_at" => %{"$gte" => beginning_of_day, "$lte" => end_of_day},
                                       "timer_id" => timer_id}) do
          {:ok, group_by_tag(pomodori)}
        end
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


  defpt group_by_tag(pomodori) do
    []
  end
end
