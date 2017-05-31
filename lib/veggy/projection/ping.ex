defmodule Veggy.Projection.Ping do
  @collection "projection.ping"

  # the initial record and the events your are interested in
  def init, do: {:ok, %{"counter" => 0}, ["Pong"]}

  # given an event tell me the record id aka the value of the field that identifies the record
  def identity(_), do: {:ok, "ping"}

  # (STORAGE) the offset of the last processed event
  def offset do
    options = [sort: %{"_offset" => -1}, projection: %{"_offset" => 1, "_id" => 0}, limit: 1]
    case Mongo.find(Veggy.MongoDB, @collection, %{}, options) |> Enum.to_list do
      [] -> {:ok, -1}
      [%{"_offset" => offset}] -> {:ok, offset}
    end
  end

  # (STORAGE) given the record id fetch it
  def fetch(record_id, record_default) do
    case Mongo.find(Veggy.MongoDB, @collection, %{"_id" => record_id}) |> Enum.to_list do
      [] -> {:ok, Map.put(record_default, "_id", record_id)}
      [d] -> {:ok, Veggy.MongoDB.from_document(d)}
    end
  end

  # (STORAGE) given the record and the offset of the last processed event, store them atomically
  def store(record, offset) do
    Mongo.save_one(Veggy.MongoDB, @collection,
      record |> Map.put("_offset", offset) |> Veggy.MongoDB.to_document)
  end

  # (STORAGE) given the record and the offset of the last processed event, delete the record
  def delete(record, offset) do
    Mongo.delete_one(Veggy.MongoDB, @collection, %{"_id" => record["_id"]})
    Mongo.save_one(Veggy.MongoDB, @collection, %{"_id" => "_offset", "_offset" => offset})
  end

  # given the event and the current record update the record accordingly
  def process(%{"event" => "Pong"}, %{"counter" => counter} = r),
    do: %{r | "counter" => counter + 1}

  # (STORAGE) given the name of the query and related parameters query appropriately the report
  def query("ping", _) do
    case Mongo.find(Veggy.MongoDB, @collection, %{}) |> Enum.to_list do
      [d] -> {:ok, d}
      _ -> {:error, :record_not_found}
    end
  end
end
