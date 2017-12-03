defmodule Veggy.MongoDB do
  use Mongo.Pool, name: __MODULE__, adapter: Mongo.Pool.Poolboy

  def child_spec, do: Supervisor.Spec.worker(__MODULE__, [connection_spec()])

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

    def in_day(day) do
      case Timex.parse(day, "{YYYY}-{0M}-{0D}") do
        {:ok, day} ->
          beginning_of_day =
            day |> Timex.beginning_of_day |> Timex.to_datetime |> Veggy.MongoDB.DateTime.from_datetime
          end_of_day =
            day |> Timex.end_of_day |> Timex.to_datetime |> Veggy.MongoDB.DateTime.from_datetime
          {:ok, beginning_of_day, end_of_day}
        {:error, reason} ->
          {:error, "day=#{day}: #{reason}"}
      end
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
          %{"key" => index_keys,
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

  defp connection_spec() do
    mongodb_uri = System.get_env("MONGODB_URI")
    connection_spec(mongodb_uri)
  end
  defp connection_spec(nil), do: [
    hostname: System.get_env("MONGODB_HOST") || "localhost",
    port: System.get_env("MONGODB_PORT") || 27017,
    database: System.get_env("MONGODB_DBNAME") || connection_database(),
    username: System.get_env("MONGODB_USERNAME"),
    password: System.get_env("MONGODB_PASSWORD"),
  ]
  defp connection_spec(uri) do
    uri_components = URI.parse(uri)
    [hostname: connection_hostname(uri_components),
     port: connection_port(uri_components),
     database: connection_database(uri_components),
     username: connection_username(uri_components),
     password: connection_password(uri_components),
    ]
  end
  defp connection_hostname(%URI{host: host}), do: host
  defp connection_port(%URI{port: port}), do: port
  defp connection_username(%URI{userinfo: nil}), do: nil
  defp connection_username(%URI{userinfo: userinfo}), do: userinfo |> String.split(":") |> List.first
  defp connection_password(%URI{userinfo: nil}), do: nil
  defp connection_password(%URI{userinfo: userinfo}), do: userinfo |> String.split(":") |> List.last
  defp connection_database(), do: connection_database(Mix.env())
  defp connection_database(%URI{path: path}), do: Path.basename(path)
  defp connection_database(:prod), do: "veggy"
  defp connection_database(env), do: "veggy_#{env}"
end
