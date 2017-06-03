defmodule Veggy.Task do
  def extract_tags(description) do
    Regex.scan(~r/#(\w+(?:[>+]\w+)*)/, description)
    |> Enum.map(&List.last/1)
    |> Enum.map(&do_explode_tag/1)
    |> List.flatten
    |> Enum.sort
    |> Enum.uniq
  end

  defp do_explode_tag(tag) do
    cond do
      String.contains?(tag, ">") ->
        do_combine_tags(">", String.split(tag, ">") |> Enum.reverse, [])
      String.contains?(tag, "+") ->
        tags = String.split(tag, "+") |> Enum.reverse
        do_combine_tags("+", tags, []) ++ tags
      true ->
        tag
    end
  end

  defp do_combine_tags(_, [], combined), do: combined
  defp do_combine_tags(">", [to_combine|rest], combined) do
    combined = [to_combine | Enum.map(combined, fn(t) -> "#{to_combine}>#{t}" end)]
    do_combine_tags(">", rest, combined)
  end
  defp do_combine_tags("+", [to_combine|rest], []), do: do_combine_tags("+", rest, [to_combine])
  defp do_combine_tags("+", [to_combine|rest], combined) do
    combined = [to_combine | Enum.map(combined, fn(t) -> "#{to_combine}>#{t}" end)]
    do_combine_tags("+", rest, combined)
  end
end
