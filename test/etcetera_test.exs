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
      assert Etcetera.get("foo", true) == %{"bar" => "baz"}
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
      assert Etcetera.get("foo", true) == value
    end

    test "get non-existent key" do
      assert Etcetera.get("foo") == nil
    end
  end

  describe "test exists? function" do
    test "set and key exists" do
      Etcetera.set("foo", "bar")
      assert Etcetera.exists?("foo")
    end

    test "set and recursive keys exist" do
      Etcetera.set("foo", %{"bar" => "baz"})
      assert Etcetera.exists?("foo")
      assert Etcetera.exists?("foo/bar")
    end

    test "non-existent key exists" do
      assert not Etcetera.exists?("foo")
    end
  end

  describe "test delete function" do
    test "set and delete key" do
      Etcetera.set("foo", "bar")
      assert Etcetera.exists?("foo")
      assert Etcetera.delete("foo") == :ok
      assert not Etcetera.exists?("foo")
      assert Etcetera.get("foo") == nil
    end

    test "set and delete directory recursively" do
      Etcetera.set("foo", %{"bar" => "baz"})
      assert Etcetera.exists?("foo")
      assert Etcetera.delete("foo") == :ok
      assert not Etcetera.exists?("foo")
      assert Etcetera.get("foo") == nil
    end

    test "delete non-existent key" do
      assert not Etcetera.exists?("foo")
      assert Etcetera.delete("foo") == {:error, "Key 'foo' does not exist"}
    end
  end

  describe "test mkdir and rmdir functions" do
    test "mkdir and dir exists" do
      assert Etcetera.mkdir("foo") == :ok
      assert Etcetera.get("foo") == nil
      assert Etcetera.exists?("foo")
    end

    test "mkdir and rmdir empty" do
      assert Etcetera.mkdir("foo") == :ok
      assert Etcetera.rmdir("foo") == :ok
      assert not Etcetera.exists?("foo")
    end

    test "mkdir and rmdir not empty" do
      assert Etcetera.mkdir("foo") == :ok
      assert Etcetera.set("foo/bar", "baz")
      assert Etcetera.rmdir("foo") == {:error, "Directory 'foo' not empty, try with recursive?: true"}
      assert Etcetera.exists?("foo")
      assert Etcetera.get("foo", true) == %{"bar" => "baz"}
    end

    test "mkdir and rmdir not empty recursive" do
      assert Etcetera.mkdir("foo") == :ok
      assert Etcetera.set("foo/bar", "baz")
      assert Etcetera.rmdir("foo", true) == :ok
      assert not Etcetera.exists?("foo")
      assert Etcetera.get("foo") == nil
    end
  end
end