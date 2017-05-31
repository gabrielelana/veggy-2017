defmodule Veggy.Projection.Pomodori do
  use Veggy.MongoDB.Projection,
    collection: "projection.pomodori",
    events: ["PomodoroStarted", "PomodoroSquashed", "PomodoroCompleted"],
    identity: "pomodoro_id"

  def process(_event, record) do
    record
  end
end
