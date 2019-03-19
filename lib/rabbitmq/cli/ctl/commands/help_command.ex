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
## Copyright (c) 2007-2019 Pivotal Software, Inc.  All rights reserved.

defmodule RabbitMQ.CLI.Ctl.Commands.HelpCommand do
  alias RabbitMQ.CLI.CommandBehaviour
  alias RabbitMQ.CLI.Core.{CommandModules, Config, ExitCodes}
  alias RabbitMQ.CLI.Ctl.Commands.CommonOptionsCommand

  @behaviour RabbitMQ.CLI.CommandBehaviour

  def scopes(), do: [:ctl, :diagnostics, :plugins]
  def switches(), do: [list_commands: :boolean]

  def distribution(_), do: :none
  use RabbitMQ.CLI.Core.MergesNoDefaults

  def validate(_, _), do: :ok

  def run([command_name | _], opts) do
    CommandModules.load(opts)

    case CommandModules.module_map()[command_name] do
      nil ->
        all_usage(opts)

      command ->
        command_usage(command, opts)
    end
  end

  def run(_, opts) do
    CommandModules.load(opts)

    case opts[:list_commands] do
      true ->
        commands_description()

      _ ->
        all_usage(opts)
    end
  end

  def output(result, _) do
    {:error, ExitCodes.exit_ok(), result}
  end

  def banner(_, _), do: nil

  def help_section(), do: :help

  def description(), do: "Displays usage information for a command"

  def usage(), do: "help (<command> | [--list-commands] [--common-options])"

  def usage_additional() do
    [
      "--list-commands: only output a list of discovered commands",
      "--common-options: display additional help for common options"
    ]
  end

  #
  # Implementation
  #

  def all_usage(opts) do
    tool_name = program_name(opts)

    Enum.join(
      tool_usage(tool_name) ++
        [Enum.join(["Available commands:"] ++ commands_description(), "\n")] ++
        help_additional(tool_name),
      "\n\n"
    ) <> "\n"
  end

  def command_usage(command, opts) do
    common_options =
      case {command, opts[:common_options]} do
        {CommonOptionsCommand, _} ->
          []

        {_, true} ->
          common_options_usage()

        {_, _} ->
          common_options_usage_short()
      end

    {command_description, additional_usage} =
      case command do
        CommonOptionsCommand ->
          {[], []}

        _ ->
          {command_description(command), additional_usage(command)}
      end

    Enum.join(
      [base_usage(command, opts)] ++ command_description ++ additional_usage ++ common_options,
      "\n\n"
    ) <>
      "\n"
  end

  defp tool_usage(tool_name) do
    [
      "\nUsage\n\n" <>
        "#{tool_name} [-n <node>] [-t <timeout>] [-l|--longnames] [-q|--quiet] <command> [<command options>]"
    ]
  end

  def base_usage(command, opts) do
    tool_name = program_name(opts)

    maybe_timeout =
      case command_supports_timeout(command) do
        true -> " [--timeout <timeout>]"
        false -> ""
      end

    Enum.join([
      "\n## Usage\n\n",
      "#{tool_name} [-n <node>] [-l] [-q] " <>
        flatten_string(command.usage(), maybe_timeout)
    ])
  end

  defp flatten_string(list, additional) when is_list(list) do
    list
    |> Enum.map(fn line -> line <> additional end)
    |> Enum.join("\n")
  end

  defp flatten_string(str, additional) when is_binary(str) do
    str <> additional
  end

  defp common_options_usage_short() do
    [
      "## Common Options

Add the --common-options argument or run `rabbitmqctl help common_options' for information about common options"
    ]
  end

  defp common_options_usage() do
    [CommonOptionsCommand.common_options_str()]
  end

  defp command_description(command) do
    [CommandBehaviour.description(command) <> ".\n"]
  end

  defp additional_usage(command) do
    command_usage =
      case CommandBehaviour.usage_additional(command) do
        list when is_list(list) -> list |> Enum.map(fn ln -> "#{ln}\n" end)
        bin when is_binary(bin) -> ["#{bin}\n"]
      end

    case command_usage do
      [] ->
        []

      usage ->
        [flatten_string(["## Arguments and options\n" | usage], "")]
    end
  end

  defp help_additional(tool_name) do
    ["Use '#{tool_name} help <command>' to learn more about a specific command"]
  end

  defp command_supports_timeout(command) do
    nil != CommandBehaviour.switches(command)[:timeout]
  end

  defp commands_description() do
    module_map = CommandModules.module_map()

    pad_commands_to =
      Enum.reduce(module_map, 0, fn {name, _}, longest ->
        name_length = String.length(name)

        case name_length > longest do
          true -> name_length
          false -> longest
        end
      end)

    module_map
    |> Enum.map(fn {name, cmd} ->
      description = CommandBehaviour.description(cmd)
      help_section = CommandBehaviour.help_section(cmd)
      {name, {description, help_section}}
    end)
    |> Enum.group_by(fn {_, {_, help_section}} -> help_section end)
    |> Enum.sort_by(fn {help_section, _} ->
      ## TODO: sort help sections
      case help_section do
        :other -> 100
        {:plugin, _} -> 99
        :help -> 1
        :node_management -> 2
        :cluster_management -> 3
        :replication -> 3
        :user_management -> 4
        :access_control -> 5
        :observability_and_health_checks -> 6
        :parameters -> 7
        :policies -> 8
        :virtual_hosts -> 9
        _ -> 98
      end
    end)
    |> Enum.map(fn {help_section, section_helps} ->
      [
        "\n## " <> section_head(help_section) <> ":\n"
        | Enum.sort(section_helps)
          |> Enum.map(fn {name, {description, _}} ->
            "   #{String.pad_trailing(name, pad_commands_to)}  #{description}"
          end)
      ]
    end)
    |> Enum.concat()
  end

  defp section_head(help_section) do
    case help_section do
      :help ->
        "Help"

      :user_management ->
        "Users"

      :cluster_management ->
        "Cluster"

      :replication ->
        "Replication"

      :node_management ->
        "Nodes"

      :queues ->
        "Queues"

      :observability_and_health_checks ->
        "Monitoring, observability and health checks"

      :virtual_hosts ->
        "Virtual hosts"

      :access_control ->
        "Access Control"

      :parameters ->
        "Parameters"

      :policies ->
        "Policies"

      :configuration ->
        "Node configuration"

      :feature_flags ->
        "Feature flags"

      :other ->
        "Other"

      {:plugin, plugin} ->
        plugin_section(plugin) <> " plugin"

      custom ->
        snake_case_to_capitalized_string(custom)
    end
  end

  defp strip_rabbitmq_prefix(value) do
    Regex.replace(~r/^rabbitmq_/, value, "")
  end

  defp format_known_plugin_name_fragments(value) do
    case value do
      ["amqp1.0"] -> "AMQP 1.0"
      ["amqp1", "0"] -> "AMQP 1.0"
      ["management"] -> "Management"
      ["management", "agent"] -> "Management"
      ["mqtt"] -> "MQTT"
      ["stomp"] -> "STOMP"
      ["web", "mqtt"] -> "Web MQTT"
      ["web", "stomp"] -> "Web STOMP"
      [other] -> snake_case_to_capitalized_string(other)
      fragments -> snake_case_to_capitalized_string(Enum.join(fragments, "_"))
    end
  end

  defp plugin_section(plugin) do
    to_string(plugin)
    # drop rabbitmq_
    |> strip_rabbitmq_prefix()
    |> String.split("_")
    |> format_known_plugin_name_fragments()
  end

  defp snake_case_to_capitalized_string(value) do
    to_string(value)
    |> String.split("_")
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end

  defp program_name(opts) do
    Config.get_option(:script_name, opts)
  end
end
