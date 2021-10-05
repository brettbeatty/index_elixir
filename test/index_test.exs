defmodule IndexTest do
  use ExUnit.Case, async: true

  {:module, IndexTest.TestModule, beam, _} =
    defmodule TestModule do
      import Index, only: [index: 1, index: 2]
      alias IndexTest.TestModule.Nested

      @attr "some attr"
      var = "some var"

      index Alfa
      index Alfa, %{with: %{complex: "args"}}
      index Alfa, with: Nested
      index Alfa, with: __MODULE__
      index Alfa, with: @attr
      index Alfa, with: var
      index {Charlie, "echo"}, "complex index"

      def f(x) do
        index Bravo
        index Bravo, %{with: %{complex: "args"}}
        index Bravo, with: Nested
        index Bravo, with: __MODULE__
        index Bravo, with: @attr
        index {Charlie, "delta"}, "complex index"
        x
      end
    end

  @beam beam

  defp entries do
    {:ok, {IndexTest.TestModule, attributes: attrs}} = :beam_lib.chunks(@beam, [:attributes])
    attrs[:index_entries]
  end

  describe "index/1" do
    test "defaults to empty list" do
      assert {Alfa, []} in entries()
    end

    test "allows indexing within function" do
      assert {Bravo, []} in entries()
    end

    test "supports complex values at module level" do
      assert {Alfa, %{with: %{complex: "args"}}} in entries()
    end

    test "supports complex values within function" do
      assert {Bravo, %{with: %{complex: "args"}}} in entries()
    end

    test "supports aliases at module level" do
      assert {Alfa, with: IndexTest.TestModule.Nested} in entries()
    end

    test "supports aliases within function" do
      assert {Bravo, with: IndexTest.TestModule.Nested} in entries()
    end

    test "supports __MODULE__ at module level" do
      assert {Alfa, with: IndexTest.TestModule} in entries()
    end

    test "supports __MODULE__ within function" do
      assert {Bravo, with: IndexTest.TestModule} in entries()
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
