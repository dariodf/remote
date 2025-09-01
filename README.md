# Remote

Compiles your project remotely and syncs back build artifacts.

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

## Usage

Remote uses the SSH adapter as default. Check how to config in [docs](https://hexdocs.pm/remote/Remote.Adapters.SSH.html).