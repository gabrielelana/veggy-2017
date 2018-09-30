defmodule Veggy.AcceptanceTest do
  use ExUnit.Case, async: true
  use Plug.Test

  import Plug.Conn

  setup_all do
    Mongo.run_command(Veggy.MongoDB, dropDatabase: 1)
  end

  test "command Ping" do
    subscribe_to_event(%{"event" => "Pong"})
    subscribe_to_event(%{"event" => "CommandSucceeded"})

    command_id = send_command(%{"command" => "Ping"})

    assert_receive {:event, %{"event" => "Pong"}}
    assert_receive {:event, %{"event" => "CommandSucceeded", "command_id" => ^command_id}}
  end

  defp subscribe_to_event(event) when is_binary(event),
    do: subscribe_to_event(%{"event" => event})

  defp subscribe_to_event(%{"event" => event}) do
    reference = Veggy.EventStore.subscribe(self(), &match?(%{"event" => ^event}, &1))

    on_exit(fn ->
      Veggy.EventStore.unsubscribe(reference)
    end)
  end

  defp send_command(command) do
    conn =
      conn(:post, "/commands", Poison.encode!(command))
      |> put_req_header("content-type", "application/json")
      |> Veggy.HTTP.call([])

    assert conn.status == 201
    assert {"content-type", "application/json"} in conn.resp_headers

    command = Poison.decode!(conn.resp_body)

    expected_location =
      "#{conn.scheme}://#{conn.host}:#{conn.port}/projections/command-status?command_id=#{
        command["_id"]
      }"

    assert {"location", expected_location} in conn.resp_headers

    Veggy.MongoDB.ObjectId.from_string(command["_id"])
  end
end
