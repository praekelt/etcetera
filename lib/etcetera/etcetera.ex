defmodule Etcetera do
  def etcd_host, do: Application.get_env(:etcetera, :etcd_host)
  def etcd_port, do: Application.get_env(:etcetera, :etcd_port)
  def etcd_user, do: Application.get_env(:etcetera, :etcd_user)
  def etcd_pass, do: Application.get_env(:etcetera, :etcd_pass)
  def etcd_prefix, do: Application.get_env(:etcetera, :etcd_prefix)
end
