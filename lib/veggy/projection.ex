defmodule Veggy.Projection do
  use GenServer

  @polling_interval 250

  # @type event_type :: String.t
  # @type event :: %{"event" => event_type}
  # @type record :: %{...}
  # @type offset :: integer
  # @type event_filter :: event_type | (event -> bool) | [event_fiter]
  # @type error :: {:error, reason :: any}
  #
  # @callback init() :: {:ok, default :: record, event_filter} | error
  # @callback identity(event) :: {:ok, record_id :: any} | error
  # @callback offset() :: {:ok, offset} | error
  # @callback fetch(record_id :: any, default :: record) :: {:ok, record} | error
  # @callback store(record, offset) :: :ok | error
  # @callback delete(record) :: :ok | error
  # @callback query(name :: String.t, parameters :: Map.t) :: {:ok, [record]} | error
  # @callback process(event, record) :: record | {:hold, expected :: event_filter} | :skip | :delete | error


  @spec events_where(module, where_clause :: {key :: atom, value :: any}, limit :: non_neg_integer) :: [Map.t]
  def events_where(module, where_clause, limit \\ 0) do
    {:ok, _, events} = module.init
    Veggy.EventStore.events_where(where_clause, to_filter(events), limit)
  end

  @spec process(module, [Map.t]) :: [Map.t]
  def process(module, events) do
    # TODO: check that module implements the Projection behaviour or at least process/2
    {:ok, pid} = Agent.start_link(fn -> %{} end)
    {:ok, default, _} = module.init

    stub = %{
      init: &module.init/0,
      identity: &module.identity/1,
      process: &module.process/2,
      fetch: fn(id, default) -> {:ok, Agent.get(pid, &Map.get(&1, id, default |> Map.put("_id", id)))} end,
      store: fn(record, _offset) -> Agent.update(pid, &Map.put(&1, record["_id"], record)) end,
      delete: fn(record, _offset) -> Agent.update(pid, &Map.delete(&1, record["_id"])) end
    }

    Enum.each(events, fn(event) ->
      try do
        do_process(stub, default, event, 0)
      rescue
        FunctionClauseError -> 0
      end
    end)

    Agent.get(pid, &Map.values(&1))
  end

  def start_link(module) do
    GenServer.start_link(__MODULE__, %{module: module})
  end

  def init(%{module: module}) do
    {:ok, default, events} = module.init
    {:ok, offset} = module.offset
    Process.send_after(self(), :process, @polling_interval)
    {:ok, %{module: module, default: default, offset: offset, filter: to_filter(events)}}
  end

  def handle_info(:process, state) do
    # IO.inspect("Poll events from EventStore after offset #{state.offset}")
    events = Veggy.EventStore.events_where({:offset_after, state.offset}, state.filter)
    # IO.inspect({:events, Enum.count(events)})
    offset = Enum.reduce(events, state.offset, &do_process(state.module, state.default, &1, &2))
    Process.send_after(self(), :process, @polling_interval)
    {:noreply, %{state|offset: offset}}
  end

  defp do_process(module, default, %{"_offset" => offset} = event, _offset) do
    with {:ok, record_id} <- call(module, :identity, [event]),
         {:ok, record} <- call(module, :fetch, [record_id, default]) do
      case call(module, :process, [event, record]) do
        :skip -> :ok
        :delete -> call(module, :delete, [record, offset])
        {:hold, _expected} -> raise "unimplemented"
        {:error, _reason} -> raise "unimplemented"
        record -> call(module, :store, [record, offset])
      end
      offset
    end
  end

  defp call(module, function, args) when is_map(module), do: apply(module[function], args)
  defp call(module, function, args) when is_atom(module), do: apply(module, function, args)

  defp to_filter(events) when is_function(events), do: events
  defp to_filter(events) when is_binary(events), do: fn(%{"event" => ^events}) -> true; (_) -> false end
  defp to_filter(events) when is_list(events) do
    if Enum.all?(events, &is_binary/1) do
      fn(%{"event" => event}) -> event in events end
    else
      to_filter(events, [])
    end
  end
  defp to_filter([], filters), do: fn(event) -> Enum.all?(filters, fn(f) -> f.(event) end) end
  defp to_filter([event|events], filters), do: to_filter(events, [to_filter(event)|filters])
end
