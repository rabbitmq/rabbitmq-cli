defmodule HoneycombFormatter do
  use GenServer

  def init(opts) do
    env = System.get_env()

    config = %{
      directory: "/tmp/honeycomb",
      github_workflow: env["GITHUB_WORKLOW"] || "unknown",
      github_run_id: env["GITHUB_RUN_ID"] || "unknown",
      github_repository: env["GITHUB_REPOSITORY"] || "unknown",
      github_sha: env["GITHUB_SHA"] || "unknown",
      github_ref: env["GITHUB_REF"] || "unknown",
      base_rmq_ref: env["BASE_RMQ_REF"] || "unknown",
      erlang_version: env["ERLANG_VERSION"] || "unknown",
      elixir_version: env["ELIXIR_VERSION"] || "unknown",
      otp_release: "unknown", # = erlang:system_info(otp_release),
      cpu_topology_json: "\"unknown\"", # = cpu_topology_json(erlang:system_info(cpu_topology)),
      schedulers: -1, # = erlang:system_info(schedulers),
      system_architecture: "unknown", # = erlang:system_info(system_architecture),
      system_memory_data_json: "\"unknown\"", # = json_string_memory(memsup:get_system_memory_data())
      exunit_seed: opts[:seed]
    }

    :ok = File.mkdir_p(config[:directory])

    {:ok, config}
  end

  def handle_cast(
        {
          :test_finished,
          %ExUnit.Test{
            module: suite,
            name: testcase,
            time: duration_microseconds,
            state: result
          }
        },
        %{directory: directory} = config
      ) do

    duration_seconds = :io_lib.format("~.6f", [duration_microseconds / 1000000]) |> IO.iodata_to_binary

    result_string = case result do
      nil -> "ok"
      r -> inspect(r)
    end

    json = "{
    \"ci\":\"GitHub Actions\",
    \"github_workflow\":\"#{config[:github_workflow]}\",
    \"github_run_id\":\"#{config[:github_run_id]}\",
    \"github_repository\":\"#{config[:github_repository]}\",
    \"github_sha\":\"#{config[:github_sha]}\",
    \"github_ref\":\"#{config[:github_ref]}\",
    \"base_rmq_ref\":\"#{config[:base_rmq_ref]}\",
    \"erlang_version\":\"#{config[:erlang_version]}\",
    \"elixir_version\":\"#{config[:elixir_version]}\",
    \"otp_release\":\"#{config[:otp_release]}\",
    \"cpu_topology\":#{config[:cpu_topology_json]},
    \"schedulers\":#{config[:schedulers]},
    \"system_architecture\":\"#{config[:system_architecture]}\",
    \"system_memory_data\":#{config[:system_memory_data_json]},
    \"suite\":\"#{suite}\",
    \"testcase\":\"#{quote_json(testcase)}\",
    \"duration_seconds\":" <> duration_seconds <> ",
    \"result\":\"#{quote_json(result_string)}\",
    \"exunit_seed\":\"#{config[:exunit_seed]}\"
    }"

    file = filename(suite, testcase, directory)
    {:ok, f} = File.open(file, [:write])
    :ok = IO.binwrite(f, json)
    :ok = File.close(f)

    {:noreply, config}
  end

  def handle_cast(_event, config) do
    {:noreply, config}
  end

  defp filename(suite, testcase, directory) do
    Path.join(directory,
      "#{System.system_time(:microsecond)}_#{escape(suite)}_#{escape(testcase)}.json")
  end

  defp escape(s) do
    s
    |> to_string()
    |> String.downcase
    |> (&(Regex.replace(~r/[^[:alnum:]]/, &1, "-"))).()
  end

  defp quote_json(s) do
    s
    |> to_string()
    |> (&(Regex.replace(~r/"/, &1, "\\\""))).()
    |> (&(Regex.replace(~r/\\e/, &1, "\\u001b"))).()
  end
end
