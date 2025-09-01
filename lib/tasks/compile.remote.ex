defmodule Mix.Tasks.Compile.Remote do
  use Mix.Task.Compiler

  @shortdoc "Compile project remotely and sync back build artifacts"

  @impl true
  def run(args) do
    {opts, _args, _} = OptionParser.parse(args, switches: [verbose: :boolean], aliases: [v: :verbose])
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
    adapter = Application.get_env(:remote, :adapter, Remote.Adapters.SSH)
    env = Mix.env()
    build_path = Mix.Project.build_path()

    IO.puts("Uploading project…")
    adapter.upload("./", verbose: verbose)

    IO.puts("Compiling remotely…")
    adapter.compile_remote(env, verbose: verbose)

    IO.puts("Downloading artifacts…")
    adapter.download("./", verbose: verbose)

    # touch manifests locally
    manifests = Path.wildcard(Path.join(build_path, "**/.mix/compile.*"))
    Enum.each(manifests, &File.touch!(&1, :os.system_time(:second)))

    {:ok, []}
  end
end
