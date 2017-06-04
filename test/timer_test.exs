defmodule Veggy.AggregateTimerTest do
  use ExUnit.Case, async: true

  setup do
    t1 = Timex.parse!("2016-10-04T13:34:35.804Z", "{RFC3339z}")
    t2 = Timex.parse!("2016-10-04T13:34:35.809Z", "{RFC3339z}")
    t3 = Timex.parse!("2016-10-04T13:34:35.814Z", "{RFC3339z}")
    t4 = Timex.parse!("2016-10-04T13:34:35.819Z", "{RFC3339z}")
    [t1: t1, t2: t2, t3: t3, t4: t4]
  end

  test "not compatible? if pomodoro starts in the middle of another", context do
    pomodori = [%{"started_at" => context[:t1],
                  "completed_at" => context[:t3]}]
    refute Veggy.Aggregate.Timer.compatible?(pomodori, context[:t2], context[:t4])
  end

  test "not compatible? if pomodoro ends in the middle of another", context do
    pomodori = [%{"started_at" => context[:t2],
                  "completed_at" => context[:t4]}]
    refute Veggy.Aggregate.Timer.compatible?(pomodori, context[:t1], context[:t3])
  end

  test "not compatible? if pomodoro starts and ends in the middle of another", context do
    pomodori = [%{"started_at" => context[:t1],
                  "completed_at" => context[:t4]}]
    refute Veggy.Aggregate.Timer.compatible?(pomodori, context[:t2], context[:t3])
  end

  test "not compatible? if in the middle starts another", context do
    pomodori = [%{"started_at" => context[:t2],
                  "completed_at" => context[:t3]}]
    refute Veggy.Aggregate.Timer.compatible?(pomodori, context[:t1], context[:t4])
  end

  test "compatible? if starts and ends before", context do
    pomodori = [%{"started_at" => context[:t3],
                  "completed_at" => context[:t4]}]
    assert Veggy.Aggregate.Timer.compatible?(pomodori, context[:t1], context[:t2])
  end

  test "compatible? if starts and ends after", context do
    pomodori = [%{"started_at" => context[:t1],
                  "completed_at" => context[:t2]}]
    assert Veggy.Aggregate.Timer.compatible?(pomodori, context[:t3], context[:t4])
  end

  test "compatible? works also for squashed pomodori", context do
    pomodori = [%{"started_at" => context[:t2],
                  "completed_at" => context[:t3]}]
    refute Veggy.Aggregate.Timer.compatible?(pomodori, context[:t1], context[:t4])
  end
end
