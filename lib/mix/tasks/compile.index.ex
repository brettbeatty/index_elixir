defmodule Mix.Tasks.Compile.Index do
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

    to_recompile
    |> Enum.map(&purge_and_get_source/1)
    |> Kernel.ParallelCompiler.compile_to_path(Mix.Project.compile_path())

    :ok
  end

  defp ls(dir) do
    case :file.list_dir(dir) do
      {:ok, files} ->
        files

      {:error, _reason} ->
        []
    end
  end

  defp get_attrs(dir, file) do
    filename = :filename.join(dir, file)

    case :beam_lib.chunks(filename, [:attributes]) do
      {:ok, {module, attributes: attrs}} ->
        [{module, attrs}]

      {:error, :beam_lib, _reason} ->
        []
    end
  end

  defp purge_and_get_source(module) do
    source = module.module_info(:compile)[:source]

    beam_file = :code.which(module)

    if :filename.extension(beam_file) == '.beam' do
      File.rm!(beam_file)
    end

    :code.purge(module)
    :code.delete(module)

    source
  end
end
