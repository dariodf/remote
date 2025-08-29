# Remote

**TODO: Add description**

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `remote` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:remote, "~> 0.1.0"}
  ]
end
```


# Remote Compiler Setup for Mix

This guide explains how to offload Elixir compilation to a remote machine using
a custom Mix compiler task. Your local project sources are synced to a remote
server, compiled there, and the compiled `_build/` and `deps/` folders are
synced back automatically.

---

## 1. Requirements

- Elixir & Erlang installed on the remote machine (via `asdf` or package manager).
- SSH access from local → remote.
- `rsync` installed on both machines.

---

## 2. SSH Setup

1. Generate an SSH key if you don’t have one:

```sh
ssh-keygen -t ed25519 -C "you@example.com"
```

2. Copy the key to the remote:

```sh
ssh-copy-id user@remote-host
```

3. Test login without password

```
ssh user@remote-host
```
