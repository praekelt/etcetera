defmodule EtceteraTest do
  use ExUnit.Case

  alias Etcetera.EtcdV2

  # TODO: Travis integration

  doctest EtcdV2

  setup do
    if EtcdV2.exists?("foo") do
      EtcdV2.delete("foo")
    end
    {:ok, %{}}
  end

  describe "test set, exists? and get functions" do
    test "set and get string value" do
      assert EtcdV2.set("foo", "bar") == :ok
      assert EtcdV2.exists?("foo")
      assert EtcdV2.get("foo") == "bar"
    end

    test "set and get int value" do
      assert EtcdV2.set("foo", 1) == :ok
      assert EtcdV2.exists?("foo")
      assert EtcdV2.get("foo") == 1
    end

    test "set and get float value" do
      assert EtcdV2.set("foo", 3.14) == :ok
      assert EtcdV2.exists?("foo")
      assert EtcdV2.get("foo") == 3.14
    end

    test "set and get boolean value" do
      assert EtcdV2.set("foo", true) == :ok
      assert EtcdV2.exists?("foo")
      assert EtcdV2.get("foo") == true
    end

    test "set and get list value" do
      assert EtcdV2.set("foo", [1, 2, 3]) == :ok
      assert EtcdV2.exists?("foo")
      assert EtcdV2.get("foo") == [1, 2, 3]
    end

    test "set and get map value" do
      assert EtcdV2.set("foo", %{"bar" => "baz"}) == :ok
      assert EtcdV2.exists?("foo")
      assert EtcdV2.get("foo", true) == %{"bar" => "baz"}
      assert EtcdV2.get("foo/bar") == "baz"
    end

    test "set and get JSON value" do
      assert EtcdV2.set("foo", "{\"key\": \"val\"}") == :ok
      assert EtcdV2.exists?("foo")
      assert EtcdV2.get("foo") == %{"key" => "val"}
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
      assert EtcdV2.set("foo", value) == :ok
      assert EtcdV2.exists?("foo")
      assert EtcdV2.get("foo", true) == value
    end

    test "get non-existent key" do
      assert EtcdV2.get("foo") == nil
    end
  end

  describe "test exists? function" do
    test "set and key exists" do
      EtcdV2.set("foo", "bar")
      assert EtcdV2.exists?("foo")
    end

    test "set and recursive keys exist" do
      EtcdV2.set("foo", %{"bar" => "baz"})
      assert EtcdV2.exists?("foo")
      assert EtcdV2.exists?("foo/bar")
    end

    test "non-existent key exists" do
      assert not EtcdV2.exists?("foo")
    end
  end

  describe "test delete function" do
    test "set and delete key" do
      EtcdV2.set("foo", "bar")
      assert EtcdV2.exists?("foo")
      assert EtcdV2.delete("foo") == :ok
      assert not EtcdV2.exists?("foo")
      assert EtcdV2.get("foo") == nil
    end

    test "set and delete directory recursively" do
      EtcdV2.set("foo", %{"bar" => "baz"})
      assert EtcdV2.exists?("foo")
      assert EtcdV2.delete("foo") == :ok
      assert not EtcdV2.exists?("foo")
      assert EtcdV2.get("foo") == nil
    end

    test "delete non-existent key" do
      assert not EtcdV2.exists?("foo")
      assert EtcdV2.delete("foo") == {:error, "Key 'foo' does not exist"}
    end
  end

  describe "test ls, mkdir and rmdir functions" do
    test "mkdir and dir exists" do
      assert EtcdV2.mkdir("foo") == :ok
      assert EtcdV2.get("foo") == nil
      assert EtcdV2.exists?("foo")
    end

    test "mkdir and rmdir empty" do
      assert EtcdV2.mkdir("foo") == :ok
      assert EtcdV2.rmdir("foo") == :ok
      assert not EtcdV2.exists?("foo")
    end

    test "mkdir and rmdir not empty" do
      assert EtcdV2.mkdir("foo") == :ok
      assert EtcdV2.set("foo/bar", "baz")
      assert EtcdV2.rmdir("foo") == {:error, "Directory 'foo' not empty, try with recursive?: true"}
      assert EtcdV2.exists?("foo")
      assert EtcdV2.get("foo", true) == %{"bar" => "baz"}
    end

    test "mkdir and rmdir not empty recursive" do
      assert EtcdV2.mkdir("foo") == :ok
      assert EtcdV2.set("foo/bar", "baz")
      assert EtcdV2.rmdir("foo", true) == :ok
      assert not EtcdV2.exists?("foo")
      assert EtcdV2.get("foo") == nil
    end

    test "mkdir and ls on empty dir" do
      assert EtcdV2.mkdir("foo") == :ok
      assert EtcdV2.ls("foo") == nil
    end

    test "set map value and ls on dir" do
      assert EtcdV2.set("foo", %{"a" => "b", "c" => "d"})
      assert EtcdV2.ls("foo") == %{"a" => "foo/a", "c" => "foo/c"}
    end

    test "ls on non-existent dir" do
      assert EtcdV2.ls("foo") == {:error, "Directory 'foo' does not exist"}
    end
  end
end
