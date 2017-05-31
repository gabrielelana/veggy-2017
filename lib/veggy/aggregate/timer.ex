defmodule Veggy.Aggregate.Timer do
  # ...

  # def fetch(id, s) do
  #   case Mongo.find(Veggy.MongoDB, "aggregate.timers", %{"_id" => id}) |> Enum.to_list do
  #     [d] -> {:ok, d |> Map.put("id", d["_id"]) |> Map.delete("_id") |> Veggy.MongoDB.from_document}
  #     _ -> {:ok, s}
  #   end
  # end

  # def store(s) do
  #   s = s |> Map.put("_id", s["id"]) |> Map.delete("id") |> Veggy.MongoDB.to_document
  #   {:ok, _} = Mongo.save_one(Veggy.MongoDB, "aggregate.timers", s)
  # end

  # ...

end
