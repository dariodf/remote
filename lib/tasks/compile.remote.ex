defmodule Mix.Tasks.Compile.Remote do
  use Mix.Task.Compiler

  @shortdoc "Compile project remotely and sync back build artifacts"

  @impl true
  def run(args) do
    case args do
      ["in_remote"] ->
        Mix.shell().info("Running remote compilation (in_remote)")
        {:ok, []}

      _ ->
        remote_compile()
    end
  end

  defp remote_compile do
    remote = System.fetch_env!("REMOTE_HOST")
    remote_path = System.fetch_env!("REMOTE_PATH")
    build_path = Mix.Project.build_path()
    env = Mix.env()

    # 1. Sync project skeleton (no deps/_build)
    run_cmd("""
    rsync -azh --delete --progress ./ #{remote}:#{remote_path}/
    """)

    # 2. Detect remote mix path inline
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

    # 3. Ensure remote deps folder exists and run mix deps.get remotely
    remote_deps_cmd = """
    ssh #{remote} 'bash -lc "\
    source ~/.bashrc >/dev/null 2>&1; \
    source ~/.profile >/dev/null 2>&1; \
    if [ -f ~/.asdf/asdf.sh ]; then source ~/.asdf/asdf.sh; fi; \
    mkdir -p #{remote_path}/deps; \
    cd #{remote_path} && \
    MIX_ENV=#{env} #{remote_mix_path} deps.get in_remote"'
    """
    run_stream_cmd(remote_deps_cmd)

    # 4. Sync deps back
    run_cmd("ssh #{remote} 'mkdir -p #{remote_path}/deps'")
    run_stream_cmd("""
    rsync -azh --delete --times --modify-window=10 --progress \
      #{remote}:#{remote_path}/deps/ ./deps/
    """)

    # 5. Ensure remote _build exists and run remote compilation
    remote_compile_cmd = """
    ssh #{remote} 'bash -lc "\
    source ~/.bashrc >/dev/null 2>&1; \
    source ~/.profile >/dev/null 2>&1; \
    if [ -f ~/.asdf/asdf.sh ]; then source ~/.asdf/asdf.sh; fi; \
    mkdir -p #{remote_path}/_build; \
    cd #{remote_path} && \
    MIX_ENV=#{env} #{remote_mix_path} compile in_remote"'
    """
    run_stream_cmd(remote_compile_cmd)

    # 6. Sync build artifacts back
    run_stream_cmd("""
    rsync -azh --delete --times --modify-window=10 --progress \
      #{remote}:#{remote_path}/_build/ ./_build/
    """)

    # 7. Touch manifests locally
    manifests = Path.wildcard(Path.join(build_path, "**/.mix/compile.*"))
    Enum.each(manifests, fn file ->
      File.touch!(file, :os.system_time(:second))
    end)

    {:ok, []}
  end

  # Run a command and wait for it
  defp run_cmd(cmd) do
    IO.puts("Running: #{cmd}")

    case System.cmd("sh", ["-c", cmd], stderr_to_stdout: true) do
      {_, 0} -> :ok
      {output, status} ->
        Mix.shell().error("Command failed (#{status}): #{cmd}\n#{output}")
        exit({:shutdown, 1})
    end
  end

  # Run a command and stream output live
  defp run_stream_cmd(cmd) do
    IO.puts("Running (streaming): #{cmd}")
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
