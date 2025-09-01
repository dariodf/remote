defmodule Remote.Adapters.SSH do
  @moduledoc """
  Default SSH adapter for remote compiler.

  ## Requirements

  - Elixir & Erlang installed on the remote machine (via `asdf` or package manager).
  - SSH access from local → remote.
  - `rsync` installed on both machines.

  ## Configuration

  ```elixir
  config :remote, Remote.Adapters.SSH,
    host: System.fetch_env!("REMOTE_HOSTNAME"),
    path: System.fetch_env!("REMOTE_PATH")
  ```

  And set your envs. For example, to test to a local folder:

  ```sh
  export REMOTE_HOSTNAME=`whoami`@localhost
  export REMOTE_PATH=/tmp/remote/
  ```

  ## SSH Setup

  1. Check if you have an SSH key and generate it if you don’t have one:

  ```sh
  ls ~/.ssh/id_*.pub

  # Run line below if no results appear
  # ssh-keygen -t ed25519 -C "your_email@example.com"
  ```

  2. Copy the key to the remote:

  ```sh
  ssh-copy-id $REMOTE_HOSTNAME
  ```

  3. Test login without password

  ```
  ssh $REMOTE_HOSTNAME
  ```

  """
  @behaviour Remote.Adapter

  def config, do: :remote |> Application.fetch_env!(__MODULE__) |> Enum.into(%{})

  @impl true
  def upload(local, opts) do
    %{host: host, path: path} = config()
    rsync_flags = flags(opts)

    run_cmd("rsync -azh --delete #{rsync_flags} #{local} #{host}:#{path}/", opts)
  end

  @impl true
  def compile_remote(env, opts) do
    %{host: host, path: path} = config()
    mix = remote_mix_path(host)

    cmd = """
    ssh #{host} 'bash -lc "\
    #{universal_source()} \
    cd #{path} && \
    MIX_ENV=#{env} #{mix} deps.get && \
    MIX_ENV=#{env} #{mix} compile in_remote"'
    """

    run_stream_cmd(cmd, opts)
  end

  @impl true
  def download(local, opts) do
    %{host: host, path: path} = config()
    rsync_flags = flags(opts)

    run_cmd(
      "rsync -azh --delete #{rsync_flags} \
    --include='_build/' \
    --include='deps/' \
    --include='node_modules/' \
    --include='priv/static/' \
    --exclude='*' \
    #{host}:#{path}/ #{local}",
      opts
    )
  end

  # --- helpers ---

  defp flags(opts), do: if(opts[:verbose], do: "--progress", else: "--quiet")

  defp run_cmd(cmd, opts) do
    if opts[:verbose], do: IO.puts("Running: #{cmd}")

    case System.cmd("sh", ["-c", cmd], stderr_to_stdout: true) do
      {_, 0} ->
        :ok

      {out, status} ->
        Mix.shell().error("Command failed (#{status}): #{cmd}\n#{out}")
        exit({:shutdown, 1})
    end
  end

  defp run_stream_cmd(cmd, opts) do
    if opts[:verbose], do: IO.puts("Running (streaming): #{cmd}")
    port = Port.open({:spawn, cmd}, [:binary, :exit_status, :stderr_to_stdout])
    stream(port)
  end

  defp stream(port) do
    receive do
      {^port, {:data, data}} ->
        IO.write(data)
        stream(port)

      {^port, {:exit_status, 0}} ->
        :ok

      {^port, {:exit_status, status}} ->
        Mix.shell().error("Remote command failed with status #{status}")
        exit({:shutdown, 1})
    end
  end

  defp remote_mix_path(host) do
    {out, status} =
      System.cmd("ssh", [host, ~s(bash -lc '#{universal_source()} command -v mix')],
        stderr_to_stdout: true
      )

    path = String.trim(out)

    if status != 0 or path == "" do
      Mix.raise("Could not find 'mix' on remote host #{host}. Check PATH and shell configs.")
    end

    path
  end

  defp universal_source do
    """
    [ -f ~/.bashrc ] && source ~/.bashrc >/dev/null 2>&1; \
    [ -f ~/.bash_profile ] && source ~/.bash_profile >/dev/null 2>&1; \
    [ -f ~/.profile ] && source ~/.profile >/dev/null 2>&1; \
    [ -f ~/.zshrc ] && source ~/.zshrc >/dev/null 2>&1; \
    [ -f ~/.zprofile ] && source ~/.zprofile >/dev/null 2>&1; \
    [ -f ~/.asdf/asdf.sh ] && source ~/.asdf/asdf.sh >/dev/null 2>&1
    """
  end
end
