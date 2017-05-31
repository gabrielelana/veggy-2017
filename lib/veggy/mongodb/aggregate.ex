defmodule Veggy.MongoDB.Aggregate do
  defmacro __using__(opts) do
    collection = Keyword.get(opts, :collection);

    quote do
      if unquote(collection) do
        @collection unquote(collection)
      else
        @collection "aggregate.#{Veggy.MongoDB.collection_name(__MODULE__)}"
      end

      def fetch(id, initial) do
        case Mongo.find(Veggy.MongoDB, @collection, %{"_id" => id}) |> Enum.to_list do
          [d] -> {:ok, d |> Map.put("id", d["_id"]) |> Map.delete("_id") |> Veggy.MongoDB.from_document}
          _ -> {:ok, initial}
        end
      end

      def store(aggregate) do
        aggregate = aggregate |> Map.put("_id", aggregate["id"]) |> Map.delete("id") |> Veggy.MongoDB.to_document
        {:ok, _} = Mongo.save_one(Veggy.MongoDB, @collection, aggregate)
      end

      defoverridable [fetch: 2, store: 1]
    end
  end
end
