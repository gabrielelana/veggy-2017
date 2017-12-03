defmodule Veggy.Projection.Pomodori do
  use Veggy.MongoDB.Projection,
    collection: "projection.pomodori",
    events: ["PomodoroStarted", "PomodoroSquashed", "PomodoroCompleted"],
    identity: "pomodoro_id"

  def process(_event, record) do
    record
  end

  def query("pomodori-of-the-day", %{"day" => day, "timer_id" => timer_id} = parameters) do
    timer_id = Veggy.MongoDB.ObjectId.from_string(timer_id)
    case Timex.parse(day, "{YYYY}-{0M}-{0D}") do
      {:ok, day} ->
        beginning_of_day =
          day |> Timex.beginning_of_day |> Timex.to_datetime |> Veggy.MongoDB.DateTime.from_datetime
        end_of_day =
          day |> Timex.end_of_day |> Timex.to_datetime |> Veggy.MongoDB.DateTime.from_datetime
        find(%{"started_at" => %{"$gte" => beginning_of_day, "$lte" => end_of_day},
               "timer_id" => timer_id,
              })
      {:error, reason} ->
        {:error, "day=#{parameters["day"]}: #{reason}"}
    end
  end
end
