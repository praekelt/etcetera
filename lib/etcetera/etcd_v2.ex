defmodule Etcetera.EtcdV2 do
  @moduledoc """
  Functions for interacting with an Etcd v2 store.
  """

  require Logger

  alias Etcetera.Utils

  # Etcd error codes
  @err_not_a_file 102
  @err_dir_not_empty 108

  #############################################################################
  # Etcd wrapper functions
  #
  # See https://etcd.io/docs/v2/api/
  #############################################################################

  def set(key, value) when is_map(value), do: set_map(key, value)
  def set(key, value) when is_list(value), do: set_list(key, value)
  def set(key, value), do: set_value(key, value)

  defp set_map(key, value) do
    Enum.each(value, fn {k, v} -> set("#{key}/#{k}", v) end)
  end

  defp set_list(key, value) do
    set(key, Jason.encode!(value))
  end

  def set_value(key, value) do
    resp = make_put(key, %{"value" => value})
    case resp.status_code do
      200 ->
        # Existing value reset
        :ok
      201 ->
        # New value created
        :ok
      401 ->
        Logger.error("The request requires authentication (insufficient credentials)")
        {:error, "Unauthorized user"}
      403 ->
        body = Jason.decode!(resp.body)
        case body["errorCode"] do
          @err_not_a_file ->
            Logger.error("Could not create key. Already exists as directory.")
            {:error, "Could not create key. Already exists as directory."}
          err_code ->
            Logger.error("Unhandled error code in set/2: #{err_code}")
            {:error, "Unhandled error code #{err_code}"}
        end
      status_code ->
        Logger.error("Unhandled status code in set/2: #{status_code}")
        {:error, "Unhandled status #{status_code}"}
    end
  end

  @doc """
  Retrieve the value associated with the given key in the Etcd store.

  If the value is a directory, and `unpack_dir?` is true, the contents of the directory are
  recursively retrieved and packed into a map which is then returned. If `unpack_dir?` is false,
  directory values will be treated as error cases.

  All values are JSON-decoded after retrieval, if possible.

  Returns the value (as described above) if it exists, `nil` if the value does not exist or is an
  empty directory, or `{:error, reason}` if something goes wrong.
  """
  def get(key, unpack_dir? \\ false) do
    resp = make_get(key)
    case resp.status_code do
      200 ->
        body = Jason.decode!(resp.body)
        if body["node"]["dir"] do
          # Key points to a directory
          case body["node"]["nodes"] do
            nil ->
              # Directory is empty
              nil
            nodes ->
              # Directory is not empty, recursively get elements and build map if unpack_dir option set
              if unpack_dir? do
                Enum.reduce(nodes, %{}, fn node, map ->
                  # Remove leading slash from key
                  k = String.trim_leading(node["key"], "/")

                  # Remove leading and trailing slashes from prefix
                  prefix = Utils.remove_slashes(Etcetera.etcd_prefix())

                  # Get rid of the leading prefix or it will be recursively added. Also add it into
                  # the split or keys with the prefix will not be grabbed properly.
                  prefix = "#{prefix}/"
                  k = k
                  |> String.split(prefix)
                  |> List.last()
                  |> String.trim_leading("/")

                  v = get(k, unpack_dir?)

                  # Get rid of preceding directories in key before putting it in the map
                  k = k
                  |> String.split("/")
                  |> List.last()
                  Map.put(map, k, v)
                end)
              else
                err_msg = "Key '#{key}' points to a directory, try with unpack_dir?: true"
                Logger.error(err_msg)
                {:error, err_msg}
              end
          end
        else
          # Key points to a non-directory value, attempt to JSON-decode it, otherwise return
          # value as-is
          value = body["node"]["value"]
          case Jason.decode(value) do
            {:ok, result} ->
              result
            {:error, _reason} ->
              value
          end
        end
      401 ->
        Logger.error("The request requires user authentication (Insufficient credentials)")
        {:error, "Unauthorized user"}
      404 ->
        Logger.debug("Key '#{key}' not found")
        nil
      status_code ->
        Logger.error("Unhandled status in get/1: #{status_code}")
        {:error, "Unhandled status #{status_code}"}
    end
  end

  @doc """
  Checks whether a value exists for the given key in the Etcd store.

  Returns `true` if a value exists for the key, `false` if not, or `{:error, reason}` if
  something goes wrong.
  """
  def exists?(key) do
    resp = make_get(key)
    case resp.status_code do
      200 ->
        true
      401 ->
        Logger.error("The request requires user authentication (Insufficient credentials)")
        {:error, "Unauthorized user"}
      404 ->
        false
      status_code ->
        Logger.error("Unhandled status in exists?/1: #{status_code}")
        {:error, "Unhandled status #{status_code}"}
    end
  end

  @doc """
  Deletes the value for the given key in the Etcd store, if it exists.

  If the value is a directory and `recursive?` is true, the directory will be recursively
  deleted (the default behaviour). If `recursive?` is false, directory values will be treated as
  error cases.

  Returns `:ok` if successful, `{:error, reason}` if not.
  """
  def delete(key, recursive? \\ true) do
    resp = make_delete(key)
    case resp.status_code do
      200 ->
        :ok
      401 ->
        Logger.error("The request requires user authentication (Insufficient credentials)")
        {:error, "Unauthorized user"}
      403 ->
        body = Jason.decode!(resp.body)
        case body["errorCode"] do
          @err_not_a_file ->
            rmdir(key, recursive?)
          err_code ->
            Logger.error("Unhandled error code in delete/1: #{err_code}")
            {:error, "Unhandled error code #{err_code}"}
        end
      404 ->
        err_msg = "Key '#{key}' does not exist"
        Logger.error(err_msg)
        {:error, err_msg}
      status_code ->
        Logger.error("Unhandled status in delete/1: #{status_code}")
        {:error, "Unhandled status #{status_code}"}
    end
  end

  @doc """
  Retrieve the top level values associated with the given key (similar to Unix `ls`).

  Values are placed in a map similar to what `get/1` returns, but only one level deep. We first
  attempt to JSON-decode the values, otherwise they are returned as-is.

  Returns a map of values (as described above) if successful, `nil` if the directory does not
  exist or is empty, or `{:error, reason}` if something goes wrong.
  """
  def ls(dirname) do
    resp = make_get(dirname)
    case resp.status_code do
      200 ->
        body = Jason.decode!(resp.body)
        if body["node"]["dir"] do
          # Value is a directory
          nodes = body["node"]["nodes"]
          case nodes do
            nil ->
              # Directory is empty
              nil
            nodes ->
              # Directory is not empty, build map
              Enum.reduce(nodes, %{}, fn node, map ->
                # Get rid of leading slash in key
                k = String.trim_leading(node["key"], "/")

                # Remove leading/trailing slashes from prefix
                prefix = Utils.remove_slashes(Etcetera.etcd_prefix())

                # Get rid of leading prefix or it will be recursively added. Also add it into
                # the split or keys with the prefix will not be grabbed properly.
                prefix = "#{prefix}"
                k = k
                |> String.split(prefix)
                |> List.last()
                |> String.trim_leading("/")

                v = k

                # Get rid of preceding directories in key before putting in map
                k = k
                |> String.split("/")
                |> List.last()
                Map.put(map, k, v)
              end)
          end
        else
          # Value is not a directory - attempt to JSON-decode, otherwise return as is
          case Jason.decode(body["node"]["value"]) do
            {:ok, result} ->
              result
            {:error, _reason} ->
              body["node"]["value"]
          end
        end
      401 ->
        Logger.error("The request requires user authentication (Insufficient credentials)")
        {:error, "Unauthorized user"}
      404 ->
        Logger.error("Directory '#{dirname}' does not exist")
        nil
      status_code ->
        Logger.error("Unhandled status in ls/1: #{status_code}")
        {:error, "Unhandled status #{status_code}"}
    end
  end

  @doc """
  Creates a directory with the given name in the Etcd store (similar to Unix `mkdir`).

  Returns `:ok` if successful, `{:error, reason}` if not.
  """
  def mkdir(dirname) do
    resp = make_put(dirname, %{dir: true})
    case resp.status_code do
      200 ->
        :ok
      201 ->
        :ok
      401 ->
        Logger.error("The request requires user authentication (Insufficient credentials)")
        {:error, "Unauthorized user"}
      403 ->
        body = Jason.decode!(resp.body)
        case body["errorCode"] do
          @err_not_a_file ->
            Logger.error("Could not create directory. Already exists #{dirname}.")
            {:error, "Could not create directory. Already exists #{dirname}."}
          err_code ->
            Logger.error("Unhandled error code in mkdir/1: #{err_code}")
            {:error, "Unhandled error code #{err_code}"}
        end
      status_code ->
        Logger.error("Unhandled status in mkdir/1: #{status_code}")
        {:error, "Unhandled status #{status_code}"}
    end
  end

  @doc """
  Removes the given directory from the Etcd store (similar to Unix `rmdir`).

  If the directory is not empty, it will be treated as an error case unless `recursive?` is true.

  Returns `:ok` if successful, `{:error, reason}` if not.
  """
  def rmdir(dirname, recursive? \\ false) do
    resp = make_delete(dirname, %{dir: true, recursive: recursive?})
    case resp.status_code do
      200 ->
        :ok
      401 ->
        Logger.error("The request requires user authentication (Insufficient credentials)")
        {:error, "Unauthorized user"}
      403 ->
        body = Jason.decode!(resp.body)
        case body["errorCode"] do
          @err_dir_not_empty ->
            Logger.warn("Directory '#{dirname}' not empty, try with recursive: true")
            {:error, "Directory not empty"}
          err_code ->
            Logger.error("Unhandled error code in rmdir/1: #{err_code}")
            {:error, "Unhandled error code #{err_code}"}
        end
      404 ->
        Logger.error("Directory '#{dirname}' does not exist")
        {:error, "Directory does not exist"}
      status_code ->
        Logger.error("Unhandled status in rmdir/1: #{status_code}")
        {:error, "Unhandled status #{status_code}"}
    end
  end

  #############################################################################
  # Private utility functions
  #############################################################################

  defp make_get(path, params \\ %{}) do
    make_request(:get, path, params)
  end

  defp make_put(path, params) do
    make_request(:put, path, params)
  end

  defp make_delete(path, params \\ %{}) do
    make_request(:delete, path, params)
  end

  defp make_request(method, path, params) do
    url = Utils.get_etcd_url(path)
    auth = [basic_auth: {Etcetera.etcd_user(), Etcetera.etcd_pass()}]

    Logger.debug("Making request to #{url} with params #{inspect(params)}")
    case HTTPoison.request(method, url, "", [], [
      params: params,
      hackney: auth,
      follow_redirect: true]
    ) do
      {:error, %HTTPoison.Error{reason: :timeout}} ->
        Logger.error("Timeout on Etcd request")
        {:error, :timeout}
      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.error("Unable to make request to Etcd: #{reason}")
        %{status_code: 503}
      {:ok, resp} ->
        Logger.debug("Response code: #{resp.status_code}")
        resp
    end
  end
end
