defmodule Veggy.MongoDB do
  use Mongo.Pool, name: __MODULE__, adapter: Mongo.Pool.Poolboy

  def child_spec do
    Supervisor.Spec.worker(__MODULE__,
      [[hostname: System.get_env("MONGODB_HOST") || "localhost",
        database: System.get_env("MONGODB_DBNAME") || dbname(),
        username: System.get_env("MONGODB_USERNAME"),
        password: System.get_env("MONGODB_PASSWORD"),
       ]])
  end

  defmodule ObjectId do
    def from_string(object_id) when is_binary(object_id) do
      %BSON.ObjectId{value: Base.decode16!(object_id, case: :lower)}
    end
  end

  defmodule DateTime do
    def utc_now, do: from_datetime(Elixir.DateTime.utc_now)

    def from_datetime(dt) do
      BSON.DateTime.from_datetime(
        {{dt.year, dt.month, dt.day},
         {dt.hour, dt.minute, dt.second, elem(dt.microsecond, 0)}})
    end

    def to_datetime(%BSON.DateTime{utc: milliseconds}) do
      {:ok, dt} = Elixir.DateTime.from_unix(milliseconds, :milliseconds)
      dt
    end
  end

  def to_document(%{__struct__: _} = d), do: d
  def to_document(%{} = d), do: d |> Enum.map(fn({k, v}) -> {k, encode(v)} end) |> Enum.into(%{})
  defp encode(%Elixir.DateTime{} = v), do: DateTime.from_datetime(v)
  defp encode(%{__struct__: _} = v), do: v
  defp encode(%{} = v), do: to_document(v)
  defp encode(v), do: v

  def from_document(%{__struct__: _} = d), do: d
  def from_document(%{} = d), do: d |> Enum.map(fn({k, v}) -> {k, decode(v)} end) |> Enum.into(%{})
  defp decode(%BSON.DateTime{} = v), do: DateTime.to_datetime(v)
  defp decode(%{__struct__: _} = v), do: v
  defp decode(%{} = v), do: from_document(v)
  defp decode(v), do: v


  def collection_name(module_name) do
    module_name
    |> Module.split
    |> List.last
    |> String.downcase
    |> Inflex.pluralize
  end

  def create_index(collection_name, index_keys) do
    Mongo.run_command(Veggy.MongoDB,
      %{createIndexes: collection_name,
        indexes: [
          %{"ns" => "#{dbname()}.#{collection_name}",
            "key" => index_keys,
            "name" => generate_index_name(index_keys)
           }
        ]})
  end

  defp generate_index_name(index_keys) do
    Enum.reduce(index_keys, "",
      fn({k,v}, "") -> "#{k}_#{v}"
        ({k,v}, s) -> s <> "_#{k}_#{v}"
      end)
  end

  defp dbname do
    case Mix.env do
      :prod -> "veggy"
      env -> "veggy_#{env}"
    end
  end
end
