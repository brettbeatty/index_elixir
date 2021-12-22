# Index
Index is an experiment in aggregating data across Elixir modules at compile time.

When compiling Elixir modules there are times it's appealing to be able to collect information from
several modules into another one. Often this is to answer questions like "Which modules do x?" in
code (I haven't found a good way to do this with compilation tracers; if you know one let me know).
This repo is an attempt to generalize the way Elixir consolidates protocols.

**Note: this repo was just an experiment; there are no plans yet to publish it to Hex.**

## Installation
The package can be installed by adding `index` to your list of dependencies in `mix.exs`:
```elixir
defp deps do
  [
    {:index, github: "brettbeatty/index_elixir"}
  ]
end
```

There is no published documentation, but the `Index` module and `mix compile.index` are documented
within their source files.

## Usage
Using Index has three steps.

First, use `Index.put/2` in the modules publishing the values you're trying to aggregate. It's a
macro, so you'll need to require `Index`. I mostly envision this being included in another macro.
```elixir
defmodule MyApp.SomeModule do
  require Index

  Index.put(MyApp.MyIndex, some: "information")

  # ...
end
```

The index can be any compile-time constant, but it'll usually be the module where you want to use
the aggregated data.

Next, use `Index.fetch/1` or `Index.get/2` to do something with the aggregated values. These macros
return lists containing tuples with 1) the module where you called `Index.put/2`; and 2) the value
put into the index.
```elixir
defmodule MyApp.MyIndex do
  require Index

  # You can use the macros to inject entries into function code
  def entries do
    Index.get(__MODULE__)
    #=> [{MyApp.SomeModule, some: "information"}, {MyApp.AnotherModule, %{another: 'value'}]
  end

  # or even decide how to compile the module
  case Index.fetch(__MODULE__) do
    {:ok, entries} ->
      @values Enum.map(entries, fn {_module, value} -> value end)
      def values, do: @values

    :error ->
      def values, do: raise "not properly compiled"
  end
end
```

Last, add `mix compile.index` to your compilers. Index currently doesn't do any manifest checking,
so modules using `Index.fetch/1` and `Index.put/2` will get recompiled every time you run
`mix compile`.
```elixir
defmodule MyApp.MixProject do
  use Mix.Project

  def project do
    [
      app: :my_app,
      # ...
      compilers: Mix.compilers() ++ [:index],
      deps: deps()
    ]
  end

  # ...
end
```

For more information about `Index` and `mix compile.index` look at the docs in the source files.
