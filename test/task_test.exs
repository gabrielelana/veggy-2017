defmodule Veggy.TaskTest do
  use ExUnit.Case, async: true

  import Veggy.Task

  test "extract plain tags" do
    assert ["foo"] == extract_tags("#foo")
    assert ["foo"] == extract_tags("#foo xxx")
    assert ["foo"] == extract_tags("xxx #foo")
    assert ["foo"] == extract_tags("xxx #foo xxx")
    assert ["bar", "foo"] == extract_tags("#foo #bar")
    assert ["bar", "foo"] == extract_tags("xxx #foo #bar")
    assert ["bar", "foo"] == extract_tags("#foo #bar xxx")
    assert ["bar", "foo"] == extract_tags("#foo xxx #bar")
    assert ["bar", "foo"] == extract_tags("xxx #foo #bar xxx")
  end

  test "extracted tags must be unique" do
    assert ["foo"] == extract_tags("#foo xxx #foo")
  end
end
