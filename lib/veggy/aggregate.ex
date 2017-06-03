defmodule Veggy.Aggregate do
  use GenServer

  # @type command :: Map.t
  # @type event :: Map.t
  # @type events :: event | [event]
  # @type commands :: command | [command] | {:forward, command} | {:chain, [command]} | {:fork, [command]}
  # @type error :: {:error, reason::any}

  # @callback route(request::any) :: {:ok, command} | error

  # @callback init(id::any) :: {:ok, initial_state::any} | error

  # @callback fetch(id::any, initial_state::any) :: {:ok, state::any} | error

  # @callback store(state::any) :: :ok | error

  # @callback check(state::any) |
  #   {:ok, state::any} |
  #   {:ok, state::any, events} |
  #   {:ok, state::any, events, command | [command]} |
  #   {:error, reason::any} |
  #   {:error, reason::any, events} |
  #   {:error, reason::any, events, command | [command]}

  # @callback handle(command, state::any) ::
  #   {:ok, events} |
  #   {:ok, events, commands} |
  #   {:error, reason::any} |
  #   {:error, reason::any, events} |
  #   {:error, reason::any, events, commands}

  # @callback rollback(command, state::any) :: {:ok, events} | error

  # @callback process(event, state::any) :: state::any | error

  defmacro __using__(_opts) do
    quote do
      # @behaviour Veggy.Aggregate

      def route(_p), do: {:error, :unknown_command}
      def fetch(_id, s), do: {:ok, s}
      def store(_s), do: :ok
      def check(s), do: {:ok, s}
      def handle(_c, _s), do: {:error, :unknown_command}
      def rollback(_c, _s), do: {:error, :unknown_command}
      def process(_e, s), do: s

      defp command(name, aggregate_id, aggregate_module \\ nil, parameters)
      defp command(name, aggregate_id, nil, parameters), do: command(name, aggregate_id, __MODULE__, parameters)
      defp command(name, aggregate_id, aggregate_module, parameters) do
        %{"command" => name,
          "aggregate_id" => aggregate_id,
          "aggregate_module" => aggregate_module,
          "_id" => Veggy.UUID.new}
        |> merge_with(parameters)
      end

      defp event(name, aggregate_id \\ nil, parameters)
      defp event(name, aggregate_id, parameters) do
        %{"event" => name,
          "aggregate_id" => aggregate_id,
          "_id" => Veggy.UUID.new}
        |> merge_with(parameters)
      end

      defp merge_with(m, o),
        do: Enum.reduce(o, m, fn({k, v}, m) -> Map.put(m, to_string(k), v) end)

      defoverridable [route: 1, fetch: 2, store: 1, check: 1, handle: 2, process: 2, rollback: 2]
    end
  end


  def start_link(id, module) do
    GenServer.start_link(__MODULE__, %{id: id, module: module, aggregate: nil})
  end

  def handle(pid, %{"command" => _} = command) do
    GenServer.cast(pid, {:handle, command})
  end
  def rollback(pid, %{"command" => _} = command) do
    GenServer.cast(pid, {:rollback, command})
  end

  def init(%{id: id, module: module}) do
    with {:ok, initial_state} <- module.init(id),
         {:ok, aggregate_state} <- module.fetch(id, initial_state),
         {:ok, aggregate_state} <- check_state(module, aggregate_state) do
      {:ok, %{id: id, module: module, aggregate: aggregate_state}}
    end
  end

  defp check_state(module, state) do
    case module.check(state) do
      {:ok, state} ->
        {:ok, state}
      {:ok, state, events} ->
        events = correlate_events(events, state, module)
        state = process_events(events, module, state)
        commit_events(events)
        {:ok, state}
      {:ok, state, events, commands} ->
        events = correlate_events(events, state, module)
        state = process_events(events, module, state)
        commit_events(events)
        route_commands(commands)
        {:ok, state}
      {:error, reason} ->
        {:error, reason}
      {:error, reason, events} ->
        events = correlate_events(events, state, module)
        process_events(events, module, state)
        commit_events(events)
        {:error, reason}
      {:error, reason, events, commands} ->
        events = correlate_events(events, state, module)
        process_events(events, module, state)
        commit_events(events)
        route_commands(commands)
        {:error, reason}
    end
  end

  def handle_cast({:handle, %{"command" => _} = command}, state) do
    Veggy.EventStore.emit(received(command))

    {outcome_event, emitted_events, related_commands} =
      handle_command(command, state.module, state.aggregate)

    # TODO: ensure every commands has what we need otherwise blow up and explain why
    # TODO: ensure every events has what we need otherwise blow up and explain why

    emitted_events = correlate_events(emitted_events, command, state.aggregate, state.module)
    outcome_event = correlate_outcome(outcome_event, emitted_events, related_commands)
    route_commands(command, related_commands)
    aggregate_state = process_events(emitted_events, state.module, state.aggregate)

    # XXX: here we have a potential inconsistency, if this process dies here
    # we have changed the aggregate state but we have not yet emitted the events
    # so the state of the aggregate is inconsistent with the emitted events.
    # We should consider to not store the aggregate state at all but to
    # regenerate it from all its events when spawned

    commit_events([outcome_event | emitted_events])

    {:noreply, %{state | aggregate: aggregate_state}}
  end

  def handle_cast({:rollback, %{"command" => _} = command}, state) do
    {outcome_event, emitted_events} =
      rollback_command(command, state.module, state.aggregate)

    # TODO: ensure every events has what we need otherwise blow up and explain why

    emitted_events = correlate_events(emitted_events, command, state.aggregate, state.module)
    outcome_event = correlate_outcome(outcome_event, emitted_events, [])
    aggregate_state = process_events(emitted_events, state.module, state.aggregate)
    commit_events([outcome_event | emitted_events])
    {:noreply, %{state | aggregate: aggregate_state}}
  end

  def handle_info({:event, event}, state) do
    aggregate_state = process_events([event], state.module, state.aggregate)
    {:noreply, %{state | aggregate: aggregate_state}}
  end

  def terminate(_, _) do
    :ok
  end


  defp handle_command(command, aggregate_module, aggregate_state) do
    case aggregate_module.handle(command, aggregate_state) do
      {:ok, event} when is_map(event) -> {succeeded(command), [event], []}
      {:ok, events} when is_list(events) -> {succeeded(command), events, []}
      {:ok, events, {_, _} = commands} -> {splitted(command), events, commands}
      {:ok, events, commands} -> {succeeded(command), events, commands}
      {:error, reason} -> {failed(command, reason), [], []}
      {:error, reason, events} -> {failed(command, reason), events, []}
      {:error, reason, events, commands} -> {failed(command, reason), events, commands}
      # TODO: blow up but before explain what we are expecting
    end
  end

  defp rollback_command(command, aggregate_module, aggregate_state) do
    case aggregate_module.rollback(command, aggregate_state) do
      {:ok, event} when is_map(event) -> {rolledback(command), [event]}
      {:ok, events} when is_list(events) -> {rolledback(command), events}
      {:error, reason} -> raise reason # TODO: do something better
      # TODO: blow up but before explain what we are expecting
    end
  end

  defp correlate_events(events, %{"command" => _, "_id" => command_id}, state, module) do
    Enum.map(events, &Map.put(&1, "command_id", command_id)) |> correlate_events(state, module)
  end
  defp correlate_events(events, state, module) do
    Enum.map(events, &Map.merge(&1, correlation_ids_in(state, module)))
  end

  defp correlation_ids_in(state, module) do
    keys = Enum.filter_map(state, fn({k, _v}) -> String.ends_with?(k, "_id") end, &elem(&1, 0))
    Map.take(state, keys)
    |> Map.put("aggregate_id", state["id"])
    |> Map.put(aggregate_id_key(module), state["id"])
  end

  defp aggregate_id_key(module) do
    "#{module |> Module.split |> List.last |> String.downcase}_id"
  end

  defp correlate_outcome(outcome, events, {_, commands}),
    do: correlate_outcome(outcome, events, commands)
  defp correlate_outcome(outcome, events, commands) do
    outcome
    |> Map.put("events", Enum.map(events, &Map.get(&1, "_id")))
    |> Map.put("commands", Enum.map(commands, &Map.get(&1, "_id")))
  end

  defp route_commands(command) when is_map(command), do: route_commands([command])
  defp route_commands(commands) do
    Enum.each(commands, &Veggy.Aggregates.handle/1) # Veggy.Transaction.FireAndForget.start(commands)
  end
  defp route_commands(parent, {:fork, commands}), do: Veggy.Transaction.ForkAndJoin.start(parent, commands)
  defp route_commands(_parent, {:chain, _commands}), do: raise "unimplemented" # Veggy.Transaction.Chain.start(parent, commands)
  defp route_commands(_parent, {:forward, _command}), do: raise "unimplemented" # Veggy.Transaction.Forward.start(parent, command)
  defp route_commands(_parent, command) when is_map(command), do: route_commands([command])
  defp route_commands(_parent, commands), do: route_commands(commands)

  defp process_events(event, aggregate_module, aggregate_state) when is_map(event),
    do: process_events([event], aggregate_module, aggregate_state)
  defp process_events(events, aggregate_module, aggregate_state) do
    aggregate_state = Enum.reduce(events, aggregate_state, &aggregate_module.process/2)
    aggregate_module.store(aggregate_state)
    aggregate_state
  end

  defp commit_events(events) do
    Enum.each(events, &Veggy.EventStore.emit/1)
  end

  defp received(%{"command" => _, "_id" => id} = command),
    do: %{"event" => "CommandReceived", "command_id" => id, "command" => command, "_id" => Veggy.UUID.new}

  defp succeeded(%{"_id" => id}),
    do: %{"event" => "CommandSucceeded", "command_id" => id, "_id" => Veggy.UUID.new}

  defp splitted(%{"_id" => id}),
    do: %{"event" => "CommandHandedOver", "command_id" => id, "_id" => Veggy.UUID.new}

  defp failed(%{"_id" => id}, reason),
    do: %{"event" => "CommandFailed", "command_id" => id, "why" => reason, "_id" => Veggy.UUID.new}

  defp rolledback(%{"_id" => id}),
    do: %{"event" => "CommandRolledBack", "command_id" => id, "_id" => Veggy.UUID.new}
end
