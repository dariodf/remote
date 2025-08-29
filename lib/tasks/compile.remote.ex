defmodule Mix.Tasks.Compile.Remote do
  use Mix.Task.Compiler

  @shortdoc "Compile project remotely and sync back build artifacts"

  @impl true
  def run(args) do
    {opts, _args, _err} = OptionParser.parse(args, switches: [verbose: :boolean], aliases: [v: :verbose])
    verbose = opts[:verbose] || false

    case args do
      ["in_remote"] ->
        Mix.shell().info("Running remote compilation (in_remote)")
        {:ok, []}

      _ ->
        remote_compile(verbose)
    end
  end

  defp remote_compile(verbose) do
    remote = System.fetch_env!("REMOTE_HOST")
    remote_path = System.fetch_env!("REMOTE_PATH")
    build_path = Mix.Project.build_path()
    env = Mix.env()
    rsync_flags = if verbose, do: "--progress", else: "--quiet"

    # 1. Sync project skeleton (no deps/_build)
    IO.puts("Syncing project skeleton...")
    run_cmd("rsync -azh --delete #{rsync_flags} ./ #{remote}:#{remote_path}/", verbose)

    # 2. Detect remote mix path
    {remote_mix_path, status} =
      System.cmd(
        "ssh",
        [remote,
         ~s(bash -lc 'source ~/.bashrc >/dev/null 2>&1; \
                       source ~/.profile >/dev/null 2>&1; \
                       if [ -f ~/.asdf/asdf.sh ]; then source ~/.asdf/asdf.sh; fi; \
                       command -v mix')],
        stderr_to_stdout: true
      )

    remote_mix_path = String.trim(remote_mix_path)

    if status != 0 or remote_mix_path == "" do
      Mix.shell().error("""
      Could not find 'mix' on remote host #{remote}.
      Make sure Elixir is installed and available in your PATH,
      and that ~/.bashrc, ~/.profile, or ~/.asdf/asdf.sh load it correctly.
      """)
      exit({:shutdown, 1})
    end

    # 3. Run remote deps.get
    IO.puts("Syncing deps on remote...")
    remote_deps_cmd = """
    ssh #{remote} 'bash -lc "\
    source ~/.bashrc >/dev/null 2>&1; \
    source ~/.profile >/dev/null 2>&1; \
    if [ -f ~/.asdf/asdf.sh ]; then source ~/.asdf/asdf.sh; fi; \
    mkdir -p #{remote_path}/deps; \
    cd #{remote_path} && \
    MIX_ENV=#{env} #{remote_mix_path} deps.get in_remote"'
    """
    run_stream_cmd(remote_deps_cmd, verbose)

    # 4. Sync deps back
    run_cmd("ssh #{remote} 'mkdir -p #{remote_path}/deps'", verbose)
    IO.puts("Syncing deps back locally...")
    run_stream_cmd("rsync -azh --delete --times --modify-window=10 #{rsync_flags} #{remote}:#{remote_path}/deps/ ./deps/", verbose)

    # 5. Run remote compilation (always show remote compile output, hide SSH command line)
    IO.puts("Running remote compilation...")
    run_stream_cmd(remote_compile_cmd(remote, remote_path, env, remote_mix_path), false)

    # 6. Sync build artifacts back
    IO.puts("Syncing build artifacts...")
    run_stream_cmd("rsync -azh --delete --times --modify-window=10 #{rsync_flags} #{remote}:#{remote_path}/_build/ ./_build/", verbose)

    # 7. Touch manifests locally
    manifests = Path.wildcard(Path.join(build_path, "**/.mix/compile.*"))
    Enum.each(manifests, &File.touch!(&1, :os.system_time(:second)))

    {:ok, []}
  end

  defp remote_compile_cmd(remote, remote_path, env, remote_mix_path) do
    """
    ssh #{remote} 'bash -lc "\
    source ~/.bashrc >/dev/null 2>&1; \
    source ~/.profile >/dev/null 2>&1; \
    if [ -f ~/.asdf/asdf.sh ]; then source ~/.asdf/asdf.sh; fi; \
    mkdir -p #{remote_path}/_build; \
    cd #{remote_path} && \
    MIX_ENV=#{env} #{remote_mix_path} compile in_remote"'
    """
  end

  # Run a command and wait for it
  defp run_cmd(cmd, verbose) do
    if verbose, do: IO.puts("Running: #{cmd}")

    case System.cmd("sh", ["-c", cmd], stderr_to_stdout: true) do
      {_, 0} -> :ok
      {output, status} ->
        Mix.shell().error("Command failed (#{status}): #{cmd}\n#{output}")
        exit({:shutdown, 1})
    end
  end

  # Run a command and stream output live
  defp run_stream_cmd(cmd, verbose) do
    if verbose, do: IO.puts("Running (streaming): #{cmd}")
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
end
