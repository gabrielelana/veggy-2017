defmodule Veggy.EventStore do
  use GenServer

  @collection "events"

  def start_link do
    offset = offset_of_last_event() + 1
    GenServer.start_link(__MODULE__, %{offset: offset, subscriptions: %{}}, name: __MODULE__)
  end

  def emit(%{"event" => _} = event) do
    GenServer.cast(__MODULE__, {:event, event})
  end

  def subscribe(pid, check) do
    reference = make_ref()
    GenServer.cast(__MODULE__, {:subscribe, reference, check, pid})
    reference
  end

  def unsubscribe(reference) do
    GenServer.cast(__MODULE__, {:unsubscribe, reference})
  end

  def events_where(query, filter \\ fn(_) -> true end, limit \\ 100)
  def events_where({:offset_after, offset}, filter, limit) do
    GenServer.call(__MODULE__, {:fetch, %{"_offset" => %{"$gt" => offset}}, filter, limit})
  end
  def events_where({:received_after, from}, filter, limit) do
    from = Veggy.MongoDB.DateTime.from_datetime(from)
    GenServer.call(__MODULE__, {:fetch, %{"_received_at" => %{"$gt" => from}}, filter, limit})
  end
  def events_where({:received_between, from, to}, filter, limit) do
    from = Veggy.MongoDB.DateTime.from_datetime(from)
    to = Veggy.MongoDB.DateTime.from_datetime(to)
    GenServer.call(__MODULE__, {:fetch, %{"_received_at" => %{"$gt" => from, "$lt" => to}}, filter, limit})
  end
  def events_where({:aggregate_id, aggregate_id}, filter, limit) do
    GenServer.call(__MODULE__, {:fetch, %{"aggregate_id" => aggregate_id}, filter, limit})
  end


  def handle_cast({:event, event}, %{subscriptions: subscriptions, offset: offset} = state) do
    event
    |> enrich(offset)
    |> store
    |> dispatch(subscriptions)
    {:noreply, %{state | offset: offset + 1}}
  end
  def handle_cast({:subscribe, reference, check, pid}, %{subscriptions: subscriptions} = state) do
    {:noreply, %{state | subscriptions: Map.put(subscriptions, reference, {check, pid})}}
  end
  def handle_cast({:unsubscribe, reference}, %{subscriptions: subscriptions} = state) do
    {:noreply, %{state | subscriptions: Map.delete(subscriptions, reference)}}
  end

  def handle_call({:fetch, query, filter, limit}, _from, state) do
    events =
      Mongo.find(Veggy.MongoDB, @collection, query, sort: %{"_offset" => 1}, limit: limit)
      |> Enum.to_list
      |> Enum.filter(filter)
      |> Enum.map(&Veggy.MongoDB.from_document/1)
    {:reply, events, state}
  end


  defp enrich(event, offset) do
    event
    |> Map.put("_received_at", Veggy.MongoDB.DateTime.utc_now)
    |> Map.put("_offset", offset)
  end

  defp store(event) do
    Mongo.save_one(Veggy.MongoDB, @collection, Veggy.MongoDB.to_document(event))
    event
  end

  defp dispatch(event, subscriptions) do
    for {_, {check, pid}} <- subscriptions, check.(event) do
      send(pid, {:event, event})
    end
  end

  defp offset_of_last_event do
    last_event = Mongo.find(Veggy.MongoDB, @collection, %{}, sort: %{"_offset" => -1}, limit: 1) |> Enum.to_list
    case last_event do
      [event] -> event["_offset"]
      _ -> 0
    end
  end
end
