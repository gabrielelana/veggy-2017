defmodule Veggy.Countdown do
  use GenServer
  alias Veggy.EventStore

  def start_link do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def start(duration, aggregate_id, command_id) do
    GenServer.call(__MODULE__, {:start, duration, aggregate_id, command_id})
  end

  def handle_call({:start, duration, aggregate_id, command_id}, _from, pomodori) do
    pomodoro_id = Veggy.UUID.new
    {:ok, reference} = :timer.send_after(duration, self(), {:completed, pomodoro_id, aggregate_id})
    {:reply, {:ok, pomodoro_id}, Map.put(pomodori, pomodoro_id, {reference, command_id})}
  end

  def handle_info({:completed, pomodoro_id, aggregate_id}, pomodori) do
    {{_, command_id}, pomodori} = Map.pop(pomodori, pomodoro_id)
    EventStore.emit(%{"event" => "PomodoroCompleted",
                      "aggregate_id" => aggregate_id,
                      "timer_id" => aggregate_id,
                      "pomodoro_id" => pomodoro_id,
                      "command_id" => command_id,
                      "_id" => Veggy.UUID.new})
    {:noreply, pomodori}
  end
end
