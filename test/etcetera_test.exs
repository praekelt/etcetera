defmodule EtceteraTest do
  use ExUnit.Case
  doctest Etcetera

  setup do
    if Etcetera.exists?("foo") do
      Etcetera.delete("foo")
    end
    {:ok, %{}}
  end

  describe "test set, exists? and get functions" do
    test "set and get string value" do
      assert Etcetera.set("foo", "bar") == :ok
      assert Etcetera.exists?("foo")
      assert Etcetera.get("foo") == "bar"
    end

    test "set and get int value" do
      assert Etcetera.set("foo", 1) == :ok
      assert Etcetera.exists?("foo")
      assert Etcetera.get("foo") == 1
    end

    test "set and get float value" do
      assert Etcetera.set("foo", 3.14) == :ok
      assert Etcetera.exists?("foo")
      assert Etcetera.get("foo") == 3.14
    end

    test "set and get boolean value" do
      assert Etcetera.set("foo", true) == :ok
      assert Etcetera.exists?("foo")
      assert Etcetera.get("foo") == true
    end

    test "set and get list value" do
      assert Etcetera.set("foo", [1, 2, 3]) == :ok
      assert Etcetera.exists?("foo")
      assert Etcetera.get("foo") == [1, 2, 3]
    end

    test "set and get map value" do
      assert Etcetera.set("foo", %{"bar" => "baz"}) == :ok
      assert Etcetera.exists?("foo")
      assert Etcetera.get("foo", unpack_dir: true) == %{"bar" => "baz"}
      assert Etcetera.get("foo/bar") == "baz"
    end

    test "set and get JSON value" do
      assert Etcetera.set("foo", "{\"key\": \"val\"}") == :ok
      assert Etcetera.exists?("foo")
      assert Etcetera.get("foo") == %{"key" => "val"}
    end

    test "set and get complicated value" do
      value = %{
        "key" => "val",
        "int" => 1,
        "inner" => %{
          "another" => "key",
        },
        "other" => %{
          "another" => "key",
        },
        "list" => [1, "str", 3.14],
      }
      assert Etcetera.set("foo", value) == :ok
      assert Etcetera.exists?("foo")
      assert Etcetera.get("foo", unpack_dir: true) == value
    end

    test "get non-existent key" do
      assert Etcetera.get("foo") == nil
    end
  end
end