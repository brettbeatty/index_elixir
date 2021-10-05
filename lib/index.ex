defmodule Index do
  @moduledoc """
  Index provides macros for aggregating data across modules at compile time.
  """

  @doc """
  Add entry with `value` to `index`.

  An index name can be any compile-time constant, but it must be unique to your intended use.
  Otherwise you'll end up with unintended entries in your index. Often it can make sense to use a
  module name as an index name since those should be unique to your application.

  Values can be indexed at either the top level of a module or within functions, but entries
  within functions can't contain runtime values like variables--indexing happens only at
  compile-time.

  ## Examples

      defmodule MyApp.SomeModule do
        import Index, only: [index: 1, index: 2]

        index MyApp.MyIndex

        def do_something do
          index MyApp.MyIndex, "some value"
          # ...
        end
      end

      defmodule MyApp.AnotherModule do
        import Index, only: [index: 2]

        def do_something(more) do
          index MyApp.MyIndex, more
        end
      end
      # => ** (RuntimeError) only literals may be indexed inside functions

  """
  defmacro index(index, value \\ []) do
    unless Module.has_attribute?(__CALLER__.module, :index_entries) do
      Module.register_attribute(__CALLER__.module, :index_entries, accumulate: true, persist: true)
    end

    if __CALLER__.function do
      Module.put_attribute(__CALLER__.module, :index_entries, expand({index, value}, __CALLER__))
    else
      quote do
        @index_entries {unquote(index), unquote(value)}
      end
    end
  end

  defp expand(ast, env) do
    ast =
      Macro.postwalk(ast, fn
        {op, _context, _args} = node when op in [:@, :__aliases__, :__MODULE__] ->
          Macro.expand(node, env)

        node ->
          node
      end)

    if Macro.quoted_literal?(ast) do
      {entry, []} = Code.eval_quoted(ast, [], env)
      entry
    else
      raise "only literals may be indexed inside functions"
    end
  end
end
