defmodule Remote.Adapter do
  @moduledoc """
  Behaviour for remote file transfer and command execution.
  """

  @callback upload(local :: String.t(), opts :: keyword()) :: :ok | no_return()
  @callback compile_remote(env :: atom(), opts :: keyword()) :: :ok | no_return()
  @callback download(local :: String.t(), opts :: keyword()) :: :ok | no_return()
end
