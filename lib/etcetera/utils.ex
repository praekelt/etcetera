defmodule Etcetera.Utils do
  @moduledoc """
  Miscellaneous utility functions.
  """

  @doc """
  Removes the leading and trailing slashes from the given string.

  ## Examples

        iex> Etcetera.Utils.remove_slashes("////a/b/c/////")
        "a/b/c"
        iex> Etcetera.Utils.remove_slashes("a/b/c")
        "a/b/c"
  """
  def remove_slashes(input_text) do
    input_text
    |> String.replace_trailing("/", "")
    |> String.replace_leading("/", "")
  end

  def get_etcd_url(path, version \\ "v2") do
    host = remove_slashes(Etcetera.etcd_host)
    port = Etcetera.etcd_port
    prefix = remove_slashes(Etcetera.etcd_prefix)
    path = remove_slashes(path)
    "#{host}:#{port}/#{version}/keys/#{prefix}/#{path}"
  end
end
