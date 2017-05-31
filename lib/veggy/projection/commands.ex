defmodule Veggy.Projection.Commands do
  use Veggy.MongoDB.Projection,
    collection: "projection.commands",
    events: &match?(%{"command_id" => _}, &1),
    indexes: [%{"command_id" => 1}],
    identity: "command_id"


  def process(%{"event" => "CommandReceived"} = event, record) do
    record
    |> Map.put("command_id", event["command_id"])
    |> Map.put("command", event["command"])
    |> Map.put("received_at", event["_received_at"])
    |> Map.put("status", "received")
  end
  def process(%{"event" => "CommandSucceeded"} = event, record) do
    received_at = record["received_at"]
    succeeded_at = event["_received_at"]
    elapsed = Timex.diff(succeeded_at, received_at, :milliseconds)
    record
    |> Map.put("status", "succeeded")
    |> Map.put("succeeded_at", event["_received_at"])
    |> Map.put("commands", Enum.concat(Map.get(record, "commands", []), Map.get(event, "commands", [])))
    |> Map.put("events", Enum.concat(Map.get(record, "events", []), Map.get(event, "events", [])))
    |> Map.put("elapsed", elapsed)
  end
  def process(%{"event" => "CommandFailed"} = event, record) do
    received_at = record["received_at"]
    failed_at = event["_received_at"]
    elapsed = Timex.diff(failed_at, received_at, :milliseconds)
    record
    |> Map.put("status", "failed")
    |> Map.put("failed_at", event["_received_at"])
    |> Map.put("why", event["why"])
    |> Map.put("commands", Enum.concat(Map.get(record, "commands", []), Map.get(event, "commands", [])))
    |> Map.put("events", Enum.concat(Map.get(record, "events", []), Map.get(event, "events", [])))
    |> Map.put("elapsed", elapsed)
  end
  def process(%{"event" => "CommandHandedOver"} = event, record) do
    record
    |> Map.put("status", "working")
    |> Map.put("commands", Enum.concat(Map.get(record, "commands", []), Map.get(event, "commands", [])))
    |> Map.put("events", Enum.concat(Map.get(record, "events", []), Map.get(event, "events", [])))
  end
  def process(%{"event" => "CommandRolledBack"} = event, record) do
    received_at = record["received_at"]
    rolledback_at = event["_received_at"]
    elapsed = Timex.diff(rolledback_at, received_at, :milliseconds)
    record
    |> Map.put("status", "rolledback")
    |> Map.put("rolledback_at", event["_received_at"])
    |> Map.put("commands", Enum.concat(Map.get(record, "commands", []), Map.get(event, "commands", [])))
    |> Map.put("events", Enum.concat(Map.get(record, "events", []), Map.get(event, "events", [])))
    |> Map.put("elapsed", elapsed)
  end
  def process(%{"_id" => event_id}, record) do
    Map.put(record, "events",
      Map.get(record, "events", [])
      |> MapSet.new
      |> MapSet.put(event_id)
      |> MapSet.to_list
    )
  end

  def query("command-status", %{"command_id" => command_id}) do
    find_one(%{"command_id" => Veggy.MongoDB.ObjectId.from_string(command_id)})
  end
end
