defmodule Veggy.Aggregate.User do
  use Veggy.Aggregate
  use Veggy.MongoDB.Aggregate, collection: "aggregate.users"

  def user_id(username), do: username

  def route(%{"command" => "Login", "username" => username}) do
    {:ok, command("Login", user_id(username), username: username)}
  end

  def init(id) do
    {:ok, %{"id" => id, "timer_id" => Veggy.UUID.new}}
  end

  def handle(%{"command" => "Login"} = c, s) do
    {:ok,
     [event("LoggedIn", username: c["username"])],
     [command("CreateTimer", s["timer_id"], Veggy.Aggregate.Timer, user_id: s["id"])]}
  end

  def process(%{"event" => "LoggedIn", "username" => username}, s),
    do: Map.put(s, "username", username)
end
