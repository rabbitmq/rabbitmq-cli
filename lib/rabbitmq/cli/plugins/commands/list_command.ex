## The contents of this file are subject to the Mozilla Public License
## Version 1.1 (the "License"); you may not use this file except in
## compliance with the License. You may obtain a copy of the License
## at http://www.mozilla.org/MPL/
##
## Software distributed under the License is distributed on an "AS IS"
## basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See
## the License for the specific language governing rights and
## limitations under the License.
##
## The Original Code is RabbitMQ.
##
## The Initial Developer of the Original Code is GoPivotal, Inc.
## Copyright (c) 2007-2017 Pivotal Software, Inc.  All rights reserved.

defmodule RabbitMQ.CLI.Plugins.Commands.ListCommand do
  @behaviour RabbitMQ.CLI.CommandBehaviour
  import RabbitCommon.Records
  use RabbitMQ.CLI.DefaultOutput

  alias RabbitMQ.CLI.Core.Helpers, as: Helpers
  alias RabbitMQ.CLI.Plugins.Helpers, as: PluginHelpers

  def formatter(), do: RabbitMQ.CLI.Formatters.Plugins

  def requires_rabbit_app_running?, do: false

  def merge_defaults([], opts), do: merge_defaults([".*"], opts)
  def merge_defaults(args, opts), do: {args, Map.merge(default_opts(), opts)}

  def switches(), do: [verbose: :boolean,
                       minimal: :boolean,
                       enabled: :boolean,
                       implicitly_enabled: :boolean,
                       rabbitmq_home: :string,
                       enabled_plugins_file: :string,
                       plugins_dir: :string]
  def aliases(), do: [v: :verbose, m: :minimal,
                      'E': :enabled, e: :implicitly_enabled]

  def validate(args, _) when length(args) > 1 do
    {:validation_failure, :too_many_args}
  end

  def validate(_, %{verbose: true, minimal: true}) do
    {:validation_failure, {:bad_argument, "Cannot set both verbose and minimal"}}
  end

  def validate(_, opts) do
    :ok
    |> validate_step(fn() -> Helpers.require_rabbit_and_plugins(opts) end)
    |> validate_step(fn() -> PluginHelpers.enabled_plugins_file(opts) end)
    |> validate_step(fn() -> Helpers.plugins_dir(opts) end)
  end

  def validate_step(:ok, step) do
    case step.() do
      {:error, err} -> {:validation_failure, err};
      _             -> :ok
    end
  end
  def validate_step({:validation_failure, err}, _) do
    {:validation_failure, err}
  end

  def usage, do: "list [pattern] [--verbose] [--minimal] [--enabled] [--implicitly-enabled]"

  def banner([pattern], _), do: "Listing plugins with pattern \"#{pattern}\" ..."

  def run([pattern], %{node: node_name} = opts) do
    %{verbose: verbose, minimal: minimal,
      enabled: only_enabled,
      implicitly_enabled: all_enabled} = opts

    all     = PluginHelpers.list(opts)
    enabled = PluginHelpers.read_enabled(opts)

    case MapSet.difference(MapSet.new(enabled), MapSet.new(PluginHelpers.plugin_names(all))) do
        %MapSet{} -> :ok;
        missing   -> IO.puts("WARNING - plugins currently enabled but missing: #{missing}~n~n")
    end
    implicit           = :rabbit_plugins.dependencies(false, enabled, all)
    enabled_implicitly = implicit -- enabled

    {status, running} =
        case remote_running_plugins(node_name) do
            :error -> {:node_down, []};
            {:ok, active} -> {:running, active}
        end

    {:ok, re} = Regex.compile(pattern)

    format = case {verbose, minimal} do
      {true, false}  -> :verbose;
      {false, true}  -> :minimal;
      {false, false} -> :normal
    end

    plugins = Enum.filter(all,
      fn(plugin) ->
        name = PluginHelpers.plugin_name(plugin)

        :rabbit_plugins.is_strictly_plugin(plugin) and
        Regex.match?(re, to_string(name)) and
        cond do
          only_enabled -> Enum.member?(enabled, name);
          all_enabled  -> Enum.member?(enabled ++ enabled_implicitly, name);
          true         -> true
        end
      end)

    %{status: status,
      format: format,
      plugins: format_plugins(plugins, format, enabled, enabled_implicitly, running)}
  end

  defp remote_running_plugins(node) do
    case :rabbit_misc.rpc_call(node, :rabbit_plugins, :running_plugins, []) do
        {:badrpc, _} -> :error
        active_with_version      -> active_with_version
    end
  end

  defp format_plugins(plugins, format, enabled, enabled_implicitly, running) do
    plugins
    |> sort_plugins
    |> Enum.map(fn(plugin) ->
        format_plugin(plugin, format, enabled, enabled_implicitly, running)
       end)
  end

  defp sort_plugins(plugins) do
    Enum.sort_by(plugins, &PluginHelpers.plugin_name/1)
  end

  defp format_plugin(plugin, :minimal, _, _, _) do
    %{name: PluginHelpers.plugin_name(plugin)}
  end
  defp format_plugin(plugin, :normal, enabled, enabled_implicitly, running) do
    plugin(name: name, version: version) = plugin
    enabled_mode = case {Enum.member?(enabled, name), Enum.member?(enabled_implicitly, name)} do
      {true, false}  -> :enabled;
      {false, true}  -> :implicit;
      {false, false} -> :not_enabled
    end
    %{name: name,
      version: version,
      running_version: running[name],
      enabled: enabled_mode,
      running: Keyword.has_key?(running, name)}
  end
  defp format_plugin(plugin, :verbose, enabled, enabled_implicitly, running) do
    normal = format_plugin(plugin, :normal, enabled, enabled_implicitly, running)
    plugin(dependencies: dependencies, description: description) = plugin
    Map.merge(normal, %{dependencies: dependencies, description: description})
  end

  defp default_opts() do
    %{minimal: false, verbose: false,
      enabled: false, implicitly_enabled: false}
  end
end
