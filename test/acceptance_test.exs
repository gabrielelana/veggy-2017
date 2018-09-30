defmodule Veggy.AcceptanceTest do
  use ExUnit.Case, async: false
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

  # @tag :skip
  test "command Login" do
    subscribe_to_event(%{"event" => "LoggedIn"})
    subscribe_to_event(%{"event" => "TimerCreated"})
    subscribe_to_event(%{"event" => "CommandSucceeded"})

    username = "gabriele"
    user_id = Veggy.Aggregate.User.user_id(username)
    command_id = send_command(%{"command" => "Login", "username" => username})

    assert_receive {:event, %{"event" => "LoggedIn", "username" => ^username}}
    assert_receive {:event, %{"event" => "TimerCreated", "user_id" => ^user_id}}
    assert_receive {:event, %{"event" => "CommandSucceeded", "command_id" => ^command_id}}
  end

  test "command StartPomodoro" do
    subscribe_to_event(%{"event" => "PomodoroStarted"})
    subscribe_to_event(%{"event" => "PomodoroCompleted"})
    subscribe_to_event(%{"event" => "CommandSucceeded"})

    timer_id = Veggy.UUID.new()

    command_id =
      send_command(%{"command" => "StartPomodoro", "timer_id" => timer_id, "duration" => 10})

    assert_receive {:event, %{"event" => "PomodoroStarted"}}
    assert_receive {:event, %{"event" => "PomodoroCompleted"}}
    assert_receive {:event, %{"event" => "CommandSucceeded", "command_id" => ^command_id}}
  end

  test "command StartPomodoro fails when another pomodoro is ticking" do
    subscribe_to_event(%{"event" => "PomodoroStarted"})
    subscribe_to_event(%{"event" => "PomodoroCompleted"})
    subscribe_to_event(%{"event" => "CommandSucceeded"})
    subscribe_to_event(%{"event" => "CommandFailed"})

    timer_id = Veggy.UUID.new()

    first_start =
      send_command(%{"command" => "StartPomodoro", "timer_id" => timer_id, "duration" => 300})

    {:event, %{"pomodoro_id" => pomodoro_id}} =
      assert_receive {:event, %{"event" => "PomodoroStarted"}}

    second_start =
      send_command(%{"command" => "StartPomodoro", "timer_id" => timer_id, "duration" => 10})

    assert_receive {:event, %{"event" => "PomodoroCompleted", "pomodoro_id" => ^pomodoro_id}}
    assert_receive {:event, %{"event" => "CommandSucceeded", "command_id" => ^first_start}}
    assert_receive {:event, %{"event" => "CommandFailed", "command_id" => ^second_start}}
  end

  test "command StartPomodoro on two different timers" do
    subscribe_to_event(%{"event" => "PomodoroStarted"})
    subscribe_to_event(%{"event" => "PomodoroCompleted"})
    subscribe_to_event(%{"event" => "CommandSucceeded"})

    first_timer_id = Veggy.UUID.new()

    first_command =
      send_command(%{"command" => "StartPomodoro", "timer_id" => first_timer_id, "duration" => 10})

    second_timer_id = Veggy.UUID.new()

    second_command =
      send_command(%{
        "command" => "StartPomodoro",
        "timer_id" => second_timer_id,
        "duration" => 10
      })

    assert_receive {:event, %{"event" => "PomodoroStarted", "timer_id" => ^first_timer_id}}
    assert_receive {:event, %{"event" => "PomodoroCompleted", "timer_id" => ^first_timer_id}}
    assert_receive {:event, %{"event" => "CommandSucceeded", "command_id" => ^first_command}}

    assert_receive {:event, %{"event" => "PomodoroStarted", "timer_id" => ^second_timer_id}}
    assert_receive {:event, %{"event" => "PomodoroCompleted", "timer_id" => ^second_timer_id}}
    assert_receive {:event, %{"event" => "CommandSucceeded", "command_id" => ^second_command}}
  end

  test "command SquashPomodoro" do
    subscribe_to_event(%{"event" => "PomodoroStarted"})
    subscribe_to_event(%{"event" => "PomodoroSquashed"})
    subscribe_to_event(%{"event" => "CommandSucceeded"})

    timer_id = Veggy.UUID.new()
    send_command(%{"command" => "StartPomodoro", "timer_id" => timer_id, "duration" => 300})

    {:event, %{"pomodoro_id" => pomodoro_id}} =
      assert_receive {:event, %{"event" => "PomodoroStarted"}}

    squash_pomodoro = send_command(%{"command" => "SquashPomodoro", "timer_id" => timer_id})

    assert_receive {:event, %{"event" => "PomodoroSquashed", "pomodoro_id" => ^pomodoro_id}}
    assert_receive {:event, %{"event" => "CommandSucceeded", "command_id" => ^squash_pomodoro}}
  end

  test "command SquashPomodoro fails when pomodoro is not ticking" do
    subscribe_to_event(%{"event" => "PomodoroSquashed"})
    subscribe_to_event(%{"event" => "CommandFailed"})

    timer_id = Veggy.UUID.new()
    command_id = send_command(%{"command" => "SquashPomodoro", "timer_id" => timer_id})

    assert_receive {:event, %{"event" => "CommandFailed", "command_id" => ^command_id}}
    refute_receive {:event, %{"event" => "PomodoroSquashed"}}
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
