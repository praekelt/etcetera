use Mix.Config

config :etcetera,
  etcd_host: System.get_env("ETCD_HOST") || "localhost",
  etcd_port: String.to_integer(System.get_env("ETCD_PORT") || "2379"),
  etcd_user: System.get_env("ETCD_USER"),
  etcd_pass: System.get_env("ETCD_PASS"),
  etcd_prefix: System.get_env("ETCD_PREFIX")

config :logger, :console,
  format: "$time $metadata[$level] $message\n"
