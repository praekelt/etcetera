defmodule Etcetera do
  @moduledoc """
  Functions for interacting with an Etcd store.
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

  def set(key, value) when is_map(value) do
    Enum.each(value, fn {k, v} -> set("#{key}/#{k}", v) end)
  end

  def set(key, value) when is_list(value) do
    set(key, Jason.encode!(value))
  end

  def set(key, value) do
    resp = make_put(key, %{"value" => value})
    case resp.status_code do
      200 ->
        :ok
      201 ->
        :ok
      401 ->
        err_msg = "The request requires authentication (insufficient credentials)"
        Logger.error(err_msg)
        {:error, err_msg}
      403 ->
        body = Jason.decode!(resp.body)
        err_msg = case body["errorCode"] do
          @err_not_a_file ->
            "Could not set key #{key}, already exists as directory"
          err_code ->
            "Unhandled error code in set/2: #{err_code}"
        end
        Logger.error(err_msg)
        {:error, err_msg}
      status_code ->
        err_msg = "Unhandled status code in set/2: #{status_code}"
        Logger.error(err_msg)
        {:error, err_msg}
    end
  end

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
                  prefix = Utils.remove_slashes(etcd_prefix())

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
        err_msg = "The request requires authentication (insufficient credentials)"
        Logger.error(err_msg)
        {:error, err_msg}
      404 ->
        Logger.debug("Key '#{key}' not found")
        nil
      status_code ->
        err_msg = "Unhandled status code in get/1: #{status_code}"
        Logger.error(err_msg)
        {:error, err_msg}
    end
  end

  def exists?(key) do
    resp = make_get(key)
    case resp.status_code do
      200 ->
        true
      401 ->
        err_msg = "The request requires authentication (insufficient credentials)"
        Logger.error(err_msg)
        {:error, err_msg}
      404 ->
        false
      status_code ->
        err_msg = "Unhandled status code in exists?/1: #{status_code}"
        Logger.error(err_msg)
        {:error, err_msg}
    end
  end

  def delete(key, recursive? \\ true) do
    resp = make_delete(key)
    case resp.status_code do
      200 ->
        :ok
      401 ->
        err_msg = "The request requires authentication (insufficient credentials)"
        Logger.error(err_msg)
        {:error, err_msg}
      403 ->
        body = Jason.decode!(resp.body)
        case body["errorCode"] do
          @err_not_a_file ->
            rmdir(key, recursive?)
          err_code ->
            err_msg = "Unhandled error code in delete/1: #{err_code}"
            Logger.error(err_msg)
            {:error, err_msg}
        end
      404 ->
        err_msg = "Key '#{key}' does not exist"
        Logger.error(err_msg)
        {:error, err_msg}
      status_code ->
        err_msg = "Unhandled status code in delete/1: #{status_code}"
        Logger.error(err_msg)
        {:error, err_msg}
    end
  end

  def mkdir(dirname) do
    resp = make_put(dirname, %{dir: true})
    case resp.status_code do
      201 ->
        :ok
      401 ->
        err_msg = "The request requires authentication (insufficient credentials)"
        Logger.error(err_msg)
        {:error, err_msg}
      403 ->
        body = Jason.decode!(resp.body)
        case body["errorCode"] do
          @err_not_a_file ->
            err_msg = "Directory '#{dirname}' already exists"
            Logger.error(err_msg)
            {:error, err_msg}
          err_code ->
            err_msg = "Unhandled error code in mkdir/1: #{err_code}"
            Logger.error(err_msg)
            {:error, err_msg}
        end
      status_code ->
        err_msg = "Unhandled status code in mkdir/1: #{status_code}"
        Logger.error(err_msg)
        {:error, err_msg}
    end
  end

  def rmdir(dirname, recursive? \\ false) do
    resp = make_delete(dirname, %{dir: true, recursive: recursive?})
    case resp.status_code do
      200 ->
        :ok
      401 ->
        err_msg = "The request requires authentication (insufficient credentials)"
        Logger.error(err_msg)
        {:error, err_msg}
      403 ->
        body = Jason.decode!(resp.body)
        case body["errorCode"] do
          @err_dir_not_empty ->
            err_msg = "Directory '#{dirname}' not empty, try with recursive?: true"
            Logger.error(err_msg)
            {:error, err_msg}
          err_code ->
            err_msg = "Unhandled error code in rmdir/1: #{err_code}"
            Logger.error(err_msg)
            {:error, err_msg}
        end
      404 ->
        err_msg = "Directory '#{dirname}' does not exist"
        Logger.error(err_msg)
        {:error, err_msg}
      status_code ->
        err_msg = "Unhandled status code in rmdir/1: #{status_code}"
        Logger.error(err_msg)
        {:error, err_msg}
    end
  end

  #############################################################################
  # Private utility functions
  #############################################################################

  defp make_get(path, params \\ %{}) do
    make_request(:get, path, params)
  end

  defp make_put(path, params \\ %{}) do
    make_request(:put, path, params)
  end

  defp make_delete(path, params \\ %{}) do
    make_request(:delete, path, params)
  end

  defp make_request(method, path, params) do
    url = Utils.get_etcd_url(etcd_host(), etcd_port(), etcd_prefix(), path)
    auth = [basic_auth: {etcd_user(), etcd_pass()}]

    Logger.debug("Making request to #{url} with params #{inspect(params)}")
    case HTTPoison.request(method, url, "", [], [
      params: params,
      hackney: auth,
      follow_redirect: true]
    ) do
      {:error, reason} ->
        Logger.error("Unable to make request to Etcd: #{reason}")
        %{status_code: 503}
      {:ok, resp} ->
        Logger.debug("Response code: #{resp.status_code}")
        resp
    end
  end

  defp etcd_host, do: Application.get_env(:etcetera, :etcd_host)
  defp etcd_port, do: Application.get_env(:etcetera, :etcd_port)
  defp etcd_user, do: Application.get_env(:etcetera, :etcd_user)
  defp etcd_pass, do: Application.get_env(:etcetera, :etcd_pass)
  defp etcd_prefix, do: Application.get_env(:etcetera, :etcd_prefix)
end
