# etcetera

A simple client for working with an Etcd store in Elixir.

## Usage

The client assumes that your Etcd store lives under a directory (your path or `ETCD_PREFIX`).
It further assumes that this directory requires authentication to access (see [Authentication](#Authentication) below).

You will need to set the following environment variables:

```bash
export ETCD_HOST=localhost
export ETCD_PORT=2379
export ETCD_USER=user
export ETCD_PASS=password
export ETCD_PREFIX=some/path/here
```

## Authentication

To set up authentication for your Etcd store, you need to add a root user and enable auth as follows:

```bash
etcdctl user add root
etcdctl auth enable
```

You will be prompted to enter a root password (`rootpw` is used as a running example here).

After auth has been enabled, you will need to add a role with read/write permission to your directory, and assign this role to your Etcd user.

It is not required, but strongly recommended that you disable guest access to the root Etcd directory. This will ensure that only the root user and your assigned user will have access to your path.

You can disable guest access with:

```bash
etcdctl -u root:rootpw role revoke guest -path '/*' -readwrite
```

You can ensure that guest access has been disabled with:

```bash
etcdctl -u root:rootpw role get guest
```

### Roles

First you will need to create a role with read/write access to your path:

```bash
etcdctl -u root:rootpw role add <rolename>
etcdctl -u root:rootpw role grant <rolename> -path '/your/path/here/*' -readwrite
```

You can revoke access from this role with:

```bash
etcdctl -u root:rootpw role revoke <rolename> -path '/your/path/here/*' -readwrite
```

You can remove the role with:

```bash
etcdctl -u root:rootpw role remove <rolename>
```

### Users

Create a user on the Etcd cluster with:

```bash
etcdctl -u root:rootpw user add <username>
```

You will be prompted to enter a user password. The password can be changed with:

```bash
etcdctl -u root:rootpw user passwd <username>
```

Then assign the role created previously to the new user with:

```
etcdctl -u root:rootpw user grant <username> -roles <rolename>
```

You can check what roles are assigned to a user with:

```
etcdctl -u root:rootpw user get <username>
```

You can also revoke a role from a user with:

```
etcdctl -u root:rootpw user revoke <username> -roles <rolename>
```

## Dependencies

- HTTPoison >= 1.8
- Jason >= 1.2
