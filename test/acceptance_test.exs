defmodule Veggy.AcceptanceTest do
  use ExUnit.Case, async: false
  use Plug.Test

  import Plug.Conn

  setup_all do
    Mongo.run_command(Veggy.MongoDB, [dropDatabase: 1])
  end

  test "command Ping" do
    subscribe_to_event %{"event" => "Pong"}

    send_command %{"command" => "Ping"}
    assert_receive {:event, %{"event" => "Pong"}}
  end

  test "command Login" do
    subscribe_to_event %{"event" => "LoggedIn"}
    subscribe_to_event %{"event" => "TimerCreated"}

    username = "gabriele"
    send_command %{"command" => "Login", "username" => username}
    assert_receive {:event, %{"event" => "LoggedIn", "username" => ^username}}
    assert_receive {:event, %{"event" => "TimerCreated", "user_id" => ^username}}
  end

  test "command StartPomodoro" do
    subscribe_to_event %{"event" => "PomodoroStarted"}
    subscribe_to_event %{"event" => "PomodoroCompleted"}

    timer_id = Veggy.UUID.new
    send_command %{"command" => "StartPomodoro", "timer_id" => timer_id, "duration" => 10}
    assert_receive {:event, %{"event" => "PomodoroStarted"}}
    assert_receive {:event, %{"event" => "PomodoroCompleted"}}
  end

  test "command StartPomodoro fails when another pomodoro is ticking" do
    subscribe_to_event %{"event" => "PomodoroStarted"}
    subscribe_to_event %{"event" => "PomodoroCompleted"}
    subscribe_to_event %{"event" => "CommandFailed"}

    timer_id = Veggy.UUID.new
    send_command %{"command" => "StartPomodoro", "timer_id" => timer_id, "duration" => 100}
    {:event, %{"pomodoro_id" => pomodoro_id}} = assert_receive {:event, %{"event" => "PomodoroStarted"}}

    command_id = send_command %{"command" => "StartPomodoro", "timer_id" => timer_id, "duration" => 10}
    command_id = Veggy.MongoDB.ObjectId.from_string(command_id)
    assert_receive {:event, %{"event" => "CommandFailed", "command_id" => ^command_id}}

    assert_receive {:event, %{"event" => "PomodoroCompleted", "pomodoro_id" => ^pomodoro_id}}
  end

  test "command StartPomodoro on two different timers" do
    subscribe_to_event %{"event" => "PomodoroStarted"}
    subscribe_to_event %{"event" => "PomodoroCompleted"}

    first_timer_id = Veggy.UUID.new
    send_command %{"command" => "StartPomodoro", "timer_id" => first_timer_id, "duration" => 10}

    second_timer_id = Veggy.UUID.new
    send_command %{"command" => "StartPomodoro", "timer_id" => second_timer_id, "duration" => 10}

    assert_receive {:event, %{"event" => "PomodoroStarted", "timer_id" => ^first_timer_id}}
    assert_receive {:event, %{"event" => "PomodoroCompleted", "timer_id" => ^first_timer_id}}
    assert_receive {:event, %{"event" => "PomodoroStarted", "timer_id" => ^second_timer_id}}
    assert_receive {:event, %{"event" => "PomodoroCompleted", "timer_id" => ^second_timer_id}}
  end

  test "command SquashPomodoro" do
    subscribe_to_event %{"event" => "PomodoroStarted"}
    subscribe_to_event %{"event" => "PomodoroSquashed"}

    timer_id = Veggy.UUID.new
    send_command %{"command" => "StartPomodoro", "timer_id" => timer_id, "duration" => 100}
    {:event, %{"pomodoro_id" => pomodoro_id}} = assert_receive {:event, %{"event" => "PomodoroStarted"}}

    send_command %{"command" => "SquashPomodoro", "timer_id" => timer_id}
    assert_receive {:event, %{"event" => "PomodoroSquashed", "pomodoro_id" => ^pomodoro_id}}
  end

  test "command SquashPomodoro fails when pomodoro is not ticking" do
    subscribe_to_event %{"event" => "PomodoroSquashed"}
    subscribe_to_event %{"event" => "CommandFailed"}

    timer_id = Veggy.UUID.new
    command_id = send_command %{"command" => "SquashPomodoro", "timer_id" => timer_id}
    command_id = Veggy.MongoDB.ObjectId.from_string(command_id)
    assert_receive {:event, %{"event" => "CommandFailed", "command_id" => ^command_id}}
    refute_receive {:event, %{"event" => "PomodoroSquashed"}}
  end



  defp subscribe_to_event(event) when is_binary(event), do: subscribe_to_event(%{"event" => event})
  defp subscribe_to_event(%{"event" => event}) do
    Veggy.EventStore.subscribe(self(), &match?(%{"event" => ^event}, &1))
  end

  defp send_command(command) do
    conn = conn(:post, "/commands", Poison.encode! command)
    |> put_req_header("content-type", "application/json")
    |> Veggy.HTTP.call([])

    assert conn.status == 201
    assert {"content-type", "application/json"} in conn.resp_headers

    command = Poison.decode!(conn.resp_body)
    expected_location = "#{conn.scheme}://#{conn.host}:#{conn.port}/projections/command-status?command_id=#{command["_id"]}"
    assert {"location", expected_location} in conn.resp_headers

    command["_id"]
  end
end
