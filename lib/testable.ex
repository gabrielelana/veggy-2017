defmodule Testable do
  defmacro __using__(_opts) do
    quote do
      import unquote(__MODULE__)
    end
  end

  defmacro defpt(head, body) do
    def_macro = if function_exported?(Mix, :env, 0) && apply(Mix, :env, []) == :test, do: :def, else: :defp
    quote do
      unquote(def_macro)(unquote(head), unquote(body))
    end
  end
end
