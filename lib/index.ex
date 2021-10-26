defmodule Index do
  @moduledoc """
  Index provides macros for aggregating data across modules at compile time.
  """

  @doc """
  Fetch entries from `index`.

  Returns `{:ok, entries}` on the compilation pass by the index compiler, where `entries` is a list
  of tuples containing the origin module and value of the entry. On prior compilations returns
  `:error`.

  ## Examples

      Index.fetch(MyApp.MyIndex)
      # => {:ok, [{MyApp.SomeModule, []}, {MyApp.SomeModule, "some value"}]}

  """
  defmacro fetch(index) do
    unless Module.has_attribute?(__CALLER__.module, :index_recompile?) do
      Module.register_attribute(__CALLER__.module, :index_recompile?, persist: true)
      Module.put_attribute(__CALLER__.module, :index_recompile?, true)
    end

    case :ets.whereis(Index.Indices) do
      :undefined ->
        quote do
          # don't warn if index unused
          _ = unquote(index)
          :error
        end

      ref when is_reference(ref) ->
        quote do
          index = unquote(index)

          entries =
            case :ets.lookup(Index.Indices, index) do
              [{^index, entries}] ->
                entries

              [] ->
                []
            end

          {:ok, entries}
        end
    end
  end

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
        require Index

        Index.put(MyApp.MyIndex, [])

        def do_something do
          Index.put(MyApp.MyIndex, "some value")
          # ...
        end
      end

      defmodule MyApp.AnotherModule do
        require Index

        def do_something(more) do
          Index.put(MyApp.MyIndex, more)
        end
      end
      # => ** (RuntimeError) only compile-time values allowed with Index macros

  """
  defmacro put(index, value) do
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
      raise "only compile-time values allowed with Index macros"
    end
  end
end
