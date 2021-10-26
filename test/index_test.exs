defmodule IndexTest do
  use ExUnit.Case, async: false

  defp define_fetch_test_module! do
    :code.purge(IndexTest.Fetch)
    :code.delete(IndexTest.Fetch)

    defmodule Fetch do
      require Index

      index = Alfa

      case Index.fetch(index) do
        {:ok, entries} ->
          @entries Map.new(entries)
          def entries, do: @entries

        :error ->
          def entries, do: raise("module not recompiled")
      end
    end
  end

  describe "fetch/1" do
    test "flags module for recompilation" do
      define_fetch_test_module!()

      assert {:index_recompile?, [true]} in IndexTest.Fetch.module_info(:attributes)
    end

    test "returns :error if not recompiled" do
      define_fetch_test_module!()

      assert_raise RuntimeError, "module not recompiled", fn ->
        apply(IndexTest.Fetch, :entries, [])
      end
    end

    test "returns {:ok, entries} when recompiled" do
      Index.Indices = :ets.new(Index.Indices, [:named_table])
      :ets.insert(Index.Indices, {Alfa, [{Charlie, "ac"}, {Delta, "ad"}]})
      :ets.insert(Index.Indices, {Bravo, [{Charlie, "bc"}, {Delta, "bd"}]})

      define_fetch_test_module!()

      expected = %{Charlie => "ac", Delta => "ad"}

      assert apply(IndexTest.Fetch, :entries, []) == expected
    end
  end

  defmodule Entry do
    require Index
    alias IndexTest.Entry.Nested

    @attr "some attr"
    var = "some var"

    Index.put(Alfa, %{with: %{complex: "args"}})
    Index.put(Alfa, with: Nested)
    Index.put(Alfa, with: __MODULE__)
    Index.put(Alfa, with: @attr)
    Index.put(Alfa, with: var)
    Index.put({Charlie, "echo"}, "complex index")

    def f(x) do
      Index.put(Bravo, %{with: %{complex: "args"}})
      Index.put(Bravo, with: Nested)
      Index.put(Bravo, with: __MODULE__)
      Index.put(Bravo, with: @attr)
      Index.put({Charlie, "delta"}, "complex index")
      x
    end
  end

  defp entries do
    for {:index_entries, [entry]} <- Entry.module_info(:attributes) do
      entry
    end
  end

  describe "put/2" do
    test "supports complex values at module level" do
      assert {Alfa, %{with: %{complex: "args"}}} in entries()
    end

    test "supports complex values within function" do
      assert {Bravo, %{with: %{complex: "args"}}} in entries()
    end

    test "supports aliases at module level" do
      assert {Alfa, with: IndexTest.Entry.Nested} in entries()
    end

    test "supports aliases within function" do
      assert {Bravo, with: IndexTest.Entry.Nested} in entries()
    end

    test "supports __MODULE__ at module level" do
      assert {Alfa, with: IndexTest.Entry} in entries()
    end

    test "supports __MODULE__ within function" do
      assert {Bravo, with: IndexTest.Entry} in entries()
    end

    test "supports module attributes at module level" do
      assert {Alfa, with: "some attr"} in entries()
    end

    test "supports module attributes within function" do
      assert {Alfa, with: "some var"} in entries()
    end

    test "supports variables at module level" do
      assert {Alfa, with: "some var"} in entries()
    end

    test "supports complex index at module level" do
      assert {{Charlie, "echo"}, "complex index"} in entries()
    end

    test "supports complex index within function" do
      assert {{Charlie, "delta"}, "complex index"} in entries()
    end
  end
end
