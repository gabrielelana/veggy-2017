defmodule Veggy.Countdown do
  use GenServer

  def start_link do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def start(duration, aggregate_id) do
    GenServer.call(__MODULE__, {:start, duration, aggregate_id})
  end

  def init(args) do
    {:ok, args}
  end

  def handle_call({:start, duration, aggregate_id}, _from, pomodori) do
    pomodoro_id = Veggy.UUID.new()

    {:ok, reference} =
      :timer.send_after(duration, self(), {:completed, pomodoro_id, aggregate_id})

    {:reply, {:ok, pomodoro_id}, Map.put(pomodori, pomodoro_id, reference)}
  end

  def handle_info({:completed, pomodoro_id, aggregate_id}, pomodori) do
    {_, pomodori} = Map.pop(pomodori, pomodoro_id)

    Veggy.Aggregates.route(%{
      "command" => "CompletePomodoro",
      "pomodoro_id" => pomodoro_id,
      "timer_id" => aggregate_id
    })

    {:noreply, pomodori}
  end
end
