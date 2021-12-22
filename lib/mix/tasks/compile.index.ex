defmodule Mix.Tasks.Compile.Index do
  @shortdoc "Compile indices"
  @moduledoc """
  Compile indices with entries from source files.

  Indices are accessed via `Index.fetch/1` and `Index.get/2`, which trigger recompilation of the
  modules in which they are used at this stage with the index entries available.
  """
  use Mix.Task.Compiler

  @impl Mix.Task.Compiler
  def run(_args) do
    Mix.Task.run("compile")

    erlang_prefix = :code.lib_dir()

    {entries, to_recompile} =
      for dir <- :code.get_path(),
          not :lists.prefix(erlang_prefix, dir),
          file <- ls(dir),
          :lists.prefix('Elixir.', file) and :filename.extension(file) == '.beam',
          {module, attrs} <- get_attrs(dir, file),
          {attr, values} when attr in [:index_entries, :index_recompile?] <- attrs,
          reduce: {%{}, []} do
        {entries, to_recompile} ->
          case attr do
            :index_entries ->
              entries =
                Enum.reduce(values, entries, fn {index, value}, entries ->
                  entry = {module, value}
                  Map.update(entries, index, [entry], &[entry | &1])
                end)

              {entries, to_recompile}

            :index_recompile? ->
              if values == [true] do
                {entries, [module | to_recompile]}
              else
                {entries, to_recompile}
              end
          end
      end

    Index.Indices = :ets.new(Index.Indices, [:named_table])
    Enum.each(entries, fn {index, entries} -> :ets.insert(Index.Indices, {index, entries}) end)

    ignore_module_conflict = Code.get_compiler_option(:ignore_module_conflict)
    Code.put_compiler_option(:ignore_module_conflict, true)

    to_recompile
    |> Enum.uniq()
    |> Enum.map(&purge_and_get_source/1)
    |> Kernel.ParallelCompiler.compile_to_path(Mix.Project.consolidation_path())

    Code.put_compiler_option(:ignore_module_conflict, ignore_module_conflict)

    :ok
  end

  @spec ls(charlist()) :: [charlist()]
  defp ls(dir) do
    case :file.list_dir(dir) do
      {:ok, files} ->
        files

      {:error, _reason} ->
        []
    end
  end

  @spec get_attrs(charlist(), charlist()) :: [{module(), [term()]}]
  defp get_attrs(dir, file) do
    filename = :filename.join(dir, file)

    case :beam_lib.chunks(filename, [:attributes]) do
      {:ok, {module, attributes: attrs}} ->
        [{module, attrs}]

      {:error, :beam_lib, _reason} ->
        []
    end
  end

  @spec purge_and_get_source(module()) :: charlist()
  defp purge_and_get_source(module) do
    source = module.module_info(:compile)[:source]

    :code.purge(module)
    :code.delete(module)

    source
  end
end
