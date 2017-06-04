defmodule Veggy.ProjectionPomodoriTest do
  use ExUnit.Case
  import Veggy.Projection.Pomodori

  test "identity" do
    assert {:ok, 1} == identity %{"pomodoro_id" => 1}
    assert {:ok, 2} == identity %{"pomodoro_id" => 2}
    assert {:error, _} = identity %{}
  end

  test "process PomodoroStarted" do
    record = %{}
    event = %{"event" => "PomodoroStarted",
              "_received_at" => :received_at,
              "pomodoro_id" => :pomodoro_id,
              "description" => :description,
              "tags" => :tags,
              "timer_id" => :timer_id,
              "aggregate_id" => :timer_id,
              "shared_with" => [],
              "duration" => :duration}

    assert %{"status" => "started"} = process event, record
    assert %{"pomodoro_id" => :pomodoro_id} = process event, record
    assert %{"started_at" => :received_at} = process event, record
    assert %{"timer_id" => :timer_id} = process event, record
    assert %{"duration" => :duration} = process event, record
    assert %{"description" => :description} = process event, record
    assert %{"tags" => :tags} = process event, record
    assert %{"shared_with" => []} = process event, record
  end

  test "process PomodoroCompleted" do
    record = %{"status" => "started"}
    event = %{"event" => "PomodoroCompleted",
              "_received_at" => :received_at,
              "pomodoro_id" => :pomodoro_id}

    assert %{"status" => "completed"} = process event, record
    assert %{"completed_at" => :received_at} = process event, record
  end

  test "process PomodoroSquashed" do
    record = %{"status" => "started"}
    event = %{"event" => "PomodoroSquashed",
              "_received_at" => :received_at,
              "pomodoro_id" => :pomodoro_id}

    assert %{"status" => "squashed"} = process event, record
    assert %{"squashed_at" => :received_at} = process event, record
  end

  test "process PomodoroVoided" do
    record = %{"status" => "started"}
    event = %{"event" => "PomodoroVoided", "pomodoro_id" => :pomodoro_id}

    assert :delete = process event, record
  end

  test "group_by_tag" do
    pomodori = [%{"status" => "completed", "duration" => 100, "tags" => ["foo"]}]
    groupped = group_by_tag(pomodori)

    assert %{"duration" => 100, "pomodori" => 1, "tag" => "foo"} in groupped
    assert 1 == Enum.count(groupped)
  end

  test "group_by_tags with multiple tags in single pomodoro" do
    pomodori = [%{"status" => "completed", "duration" => 100, "tags" => ["foo", "bar"]}]
    groupped = group_by_tag(pomodori)

    assert %{"duration" => 100, "pomodori" => 1, "tag" => "bar"} in groupped
    assert %{"duration" => 100, "pomodori" => 1, "tag" => "foo"} in groupped
    assert 2 == Enum.count(groupped)
  end

  test "group_by_tags pomodori and duration will sum on the same tag" do
    pomodori = [%{"status" => "completed", "duration" => 100, "tags" => ["foo", "bar"]},
                %{"status" => "completed", "duration" => 100, "tags" => ["foo"]}]
    groupped = group_by_tag(pomodori)

    assert %{"duration" => 100, "pomodori" => 1, "tag" => "bar"} in groupped
    assert %{"duration" => 200, "pomodori" => 2, "tag" => "foo"} in groupped
    assert 2 == Enum.count(groupped)
  end

  test "group_by_tags will skip pomodori not completed" do
    pomodori = [%{"status" => "started", "duration" => 100, "tags" => ["foo", "bar"]},
                %{"status" => "completed", "duration" => 100, "tags" => ["foo"]}]
    groupped = group_by_tag(pomodori)

    assert %{"duration" => 100, "pomodori" => 1, "tag" => "foo"} in groupped
    assert 1 == Enum.count(groupped)
  end

  test "group_by_tags will ignore pomodori withtout tags" do
    pomodori = [%{"status" => "started", "duration" => 100, "tags" => []},
                %{"status" => "completed", "duration" => 100, "tags" => ["foo"]}]
    groupped = group_by_tag(pomodori)

    assert %{"duration" => 100, "pomodori" => 1, "tag" => "foo"} in groupped
    assert 1 == Enum.count(groupped)
  end
end
