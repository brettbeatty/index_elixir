defmodule IndexTest do
  use ExUnit.Case
  doctest Index

  test "greets the world" do
    assert Index.hello() == :world
  end
end
