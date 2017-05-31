defmodule Veggy.WS do
  @behaviour :cowboy_websocket_handler
  @timeout 60000

  def init(_, _req, _opts) do
    {:upgrade, :protocol, :cowboy_websocket}
  end

  def websocket_init(_type, req, _opts) do
    Veggy.EventStore.subscribe(self(), &match?(%{"event" => _}, &1))
    {:ok, req, %{}, @timeout}
  end

  def websocket_handle({:text, "ping"}, req, state) do
    message = Poison.encode!(%{message: "pong"})
    {:reply, {:text, message}, req, state}
  end
  def websocket_handle({_kind, _message}, req, state) do
    {:ok, req, state}
  end

  def websocket_info({:event, event}, req, state) do
    {:reply, {:text, Poison.encode!(event)}, req, state}
  end
  def websocket_info(_message, req, state) do
    {:ok, req, state}
  end

  def websocket_terminate(_reason, _req, _state) do
    :ok
  end
end
