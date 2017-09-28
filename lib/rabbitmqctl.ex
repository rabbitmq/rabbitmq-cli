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


defmodule RabbitMQCtl do
  alias RabbitMQ.CLI.Core.Distribution,  as: Distribution

  alias RabbitMQ.CLI.Ctl.Commands.HelpCommand, as: HelpCommand
  alias RabbitMQ.CLI.Core.Output, as: Output
  alias RabbitMQ.CLI.Core.ExitCodes, as: ExitCodes

  alias RabbitMQ.CLI.Core.Helpers, as: Helpers
  alias RabbitMQ.CLI.Core.Parser, as: Parser

  alias RabbitMQ.CLI.Core.CommandModules, as: CommandModules

  # Enable unit tests for private functions
  @compile if Mix.env == :test, do: :export_all

  @type options() :: map()
  @type command_result() :: {:error, ExitCodes.exit_code, term()} | term()

  def main(["--auto-complete" | []]) do
    handle_shutdown(:ok)
  end
  def main(["--auto-complete", script_name | args]) do
    script_basename = Path.basename(script_name)
    auto_complete(script_basename, args)
  end
  def main(unparsed_command) do
    exec_command(unparsed_command, &process_output/3)
    |> handle_shutdown
  end

  def exec_command(unparsed_command, output_fun) do
    {command, command_name, arguments, parsed_options, invalid} =
      Parser.parse(unparsed_command)
    case {command, invalid} do
      {:no_command, _} ->
        command_not_found_string = case command_name do
          "" -> ""
          _  -> "\nCommand '#{command_name}' not found. \n"
        end
        usage_string = command_not_found_string <>
                       HelpCommand.all_usage(parsed_options)
        {:error, ExitCodes.exit_usage, usage_string};
      {{:suggest, suggested}, _} ->
        suggest_message = "\nCommand '#{command_name}' not found. \n"<>
                          "Did you mean '#{suggested}'? \n"
        {:error, ExitCodes.exit_usage, suggest_message};
      {_, [_|_]} ->

        argument_validation_error_output({:bad_option, invalid}, command,
          unparsed_command, parsed_options);
      _ ->
        options = parsed_options |> merge_all_defaults |> normalize_options
        {arguments, options} = command.merge_defaults(arguments, options)

        with_distribution(options, fn() ->
          # The code below implements a tiny decision tree that has
          # to do with CLI argument and environment state validation.

          # validate CLI arguments
          case command.validate(arguments, options) do
            :ok ->
              # then optionally validate execution environment
              case maybe_validate_execution_environment(command, arguments, options) do
                :ok                        ->
                  result = proceed_to_execution(command, arguments, options)
                  handle_command_output(result, command, options, output_fun);
                {:validation_failure, err} ->
                  environment_validation_error_output(err, command, unparsed_command, options);
                {:error, _} = err ->
                  format_error(err, options, command)
              end
            {:validation_failure, err} ->
              argument_validation_error_output(err, command, unparsed_command, options);
            {:error, _} = err ->
              format_error(err, options, command)
          end
        end)
    end
  end

  defp maybe_validate_execution_environment(command, arguments, options) do
    case function_exported?(command, :validate_execution_environment, 2) do
      false -> :ok
      true  -> command.validate_execution_environment(arguments, options)
    end
  end

  defp proceed_to_execution(command, arguments, options) do
    maybe_print_banner(command, arguments, options)
    maybe_run_command(command, arguments, options)
  end

  defp maybe_run_command(_, _, %{dry_run: true}) do
    :ok
  end
  defp maybe_run_command(command, arguments, options) do
    try do
      command.run(arguments, options) |> command.output(options)
    catch _error_type, error ->
      {:error, ExitCodes.exit_software,
       to_string(:io_lib.format("Error: ~n~p~n Stacktrace ~p~n",
                                [error, System.stacktrace()]))}
    end
  end

  def handle_command_output(output, command, options, output_fun) do
    case output do
      {:error, _, _} = err ->
        err;
      {:error, _} = err ->
        format_error(err, options, command);
      _  ->
        output_fun.(output, command, options)
    end
  end

  defp process_output(output, command, options) do
    formatter = get_formatter(command, options)
    printer = get_printer(options)

    output
    |> Output.format_output(formatter, options)
    |> Output.print_output(printer, options)
    |> case do
         {:error, _} = err -> format_error(err, options, command);
         other             -> other
       end
  end

  defp handle_shutdown({:error, exit_code, output}) do
    output_device = case exit_code == ExitCodes.exit_ok do
      true  -> :stdio;
      false -> :stderr
    end

    for line <- List.flatten([output]) do
      IO.puts(output_device, Helpers.string_or_inspect(line))
    end
    exit_program(exit_code)
  end
  defp handle_shutdown(_) do
    exit_program(ExitCodes.exit_ok)
  end

  def auto_complete(script_name, args) do
    Rabbitmq.CLI.AutoComplete.complete(script_name, args)
    |> Stream.map(&IO.puts/1) |> Stream.run
    exit_program(ExitCodes.exit_ok)
  end

  def merge_all_defaults(%{} = options) do
    options
    |> merge_defaults_node
    |> merge_defaults_timeout
    |> merge_defaults_longnames
  end

  defp merge_defaults_node(%{} = opts) do
    Map.merge(%{node: Helpers.get_rabbit_hostname()}, opts)
  end

  defp merge_defaults_timeout(%{} = opts), do: Map.merge(%{timeout: :infinity}, opts)

  defp merge_defaults_longnames(%{} = opts), do: Map.merge(%{longnames: false}, opts)

  defp normalize_options(opts) do
    opts
    |> normalize_node
    |> normalize_timeout
  end

  defp normalize_node(%{node: node} = opts) do
    Map.merge(opts, %{node: Helpers.parse_node(node)})
  end

  defp normalize_timeout(%{timeout: timeout} = opts)
  when is_integer(timeout) do
    Map.put(opts, :timeout, timeout * 1000)
  end
  defp normalize_timeout(opts) do
    opts
  end

  defp get_formatter(command, %{formatter: formatter}) do
    module_name = Module.safe_concat("RabbitMQ.CLI.Formatters", Macro.camelize(formatter))
    case Code.ensure_loaded(module_name) do
      {:module, _}      -> module_name;
      {:error, :nofile} -> default_formatter(command)
    end
  end
  defp get_formatter(command, _) do
    default_formatter(command)
  end

  defp get_printer(%{printer: printer}) do
    module_name = String.to_atom("RabbitMQ.CLI.Printers." <> Macro.camelize(printer))
    case Code.ensure_loaded(module_name) do
      {:module, _}      -> module_name;
      {:error, :nofile} -> default_printer()
    end
  end
  defp get_printer(_) do
    default_printer()
  end

  def default_printer() do
    RabbitMQ.CLI.Printers.StdIO
  end

  def default_formatter(command) do
    case function_exported?(command, :formatter, 0) do
      true  -> command.formatter;
      false -> RabbitMQ.CLI.Formatters.String
    end
  end

  # Suppress banner if --quiet option is provided
  defp maybe_print_banner(_, _, %{quiet: true}) do
    nil
  end
  # Suppress banner if a machine-readable formatter is used
  defp maybe_print_banner(_, _, %{formatter: "csv"}) do
    nil
  end
  defp maybe_print_banner(_, _, %{formatter: "json"}) do
    nil
  end
  defp maybe_print_banner(command, args, opts) do
    case command.banner(args, opts) do
      nil -> nil
      banner ->
        case banner do
          list when is_list(list) ->
            for line <- list, do: IO.puts(line);
          binary when is_binary(binary) ->
            IO.puts(binary)
        end
    end
  end

  def argument_validation_error_output(err_detail, command, unparsed_command, options) do
    err = format_validation_error(err_detail)
    base_error = "Error (argument validation): #{err}\nArguments given:\n\t#{unparsed_command |> Enum.join(" ")}"
    validation_error_output(err_detail, base_error, command, options)
  end

  def environment_validation_error_output(err_detail, command, unparsed_command, options) do
    err = format_validation_error(err_detail)
    base_error = "Error: #{err}\nArguments given:\n\t#{unparsed_command |> Enum.join(" ")}"
    validation_error_output(err_detail, base_error, command, options)
  end

  defp validation_error_output(err_detail, base_error, command, options) do
    usage = HelpCommand.base_usage(command, options)
    message = base_error <> "\n" <> usage
    {:error, ExitCodes.exit_code_for(command, {:validation_failure, err_detail}), message}
  end

  defp format_validation_error(:not_enough_args), do: "not enough arguments."
  defp format_validation_error({:not_enough_args, detail}), do: "not enough arguments. #{detail}"
  defp format_validation_error(:too_many_args), do: "too many arguments."
  defp format_validation_error({:too_many_args, detail}), do: "too many arguments. #{detail}"
  defp format_validation_error(:bad_argument), do: "Bad argument."
  defp format_validation_error({:bad_argument, detail}), do: "Bad argument. #{detail}"
  defp format_validation_error({:bad_option, opts}) do
    header = "Invalid options for this command:"
    Enum.join([header | for {key, val} <- opts do "#{key} : #{val}" end], "\n")
  end
  defp format_validation_error({:bad_info_key, keys}), do: "Info key(s) #{Enum.join(keys, ",")} are not supported"
  defp format_validation_error(:rabbit_app_is_stopped), do: "this command requires the 'rabbit' app to be running on the target node. Start it with 'rabbitmqctl start_app'."
  defp format_validation_error(:rabbit_app_is_running), do: "this command requires the 'rabbit' app to be stopped on the target node. Stop it with 'rabbitmqctl stop_app'."
  defp format_validation_error(err), do: inspect err

  defp exit_program(code) do
    :net_kernel.stop
    exit({:shutdown, code})
  end

  defp format_error({:error, {:badrpc_multi, :nodedown, [node | _]} = result}, opts, command) do
    diagnostics = get_node_diagnostics(node)
    {:error, ExitCodes.exit_code_for(command, result),
     badrpc_error_message_header(node, opts) <> diagnostics}
  end
  defp format_error({:error, {:badrpc_multi, :timeout, [node | _]} = result}, opts, module) do
    op = CommandModules.module_to_command(module)
    {:error, ExitCodes.exit_code_for(op, result),
     "Error: operation #{op} on node #{node} timed out. Timeout value used: #{opts[:timeout]}"}
  end
  defp format_error({:error, {:badrpc, :nodedown} = result}, opts, command) do
    diagnostics = get_node_diagnostics(opts[:node])
    {:error, ExitCodes.exit_code_for(command, result),
     badrpc_error_message_header(opts[:node], opts) <> diagnostics}
  end
  defp format_error({:error, {:badrpc, :timeout} = result}, opts, module) do
    op = CommandModules.module_to_command(module)
    {:error, ExitCodes.exit_code_for(op, result),
     "Error: operation #{op} on node #{opts[:node]} timed out. Timeout value used: #{opts[:timeout]}"}
  end
  defp format_error({:error, {:badrpc, {:timeout, to}} = result}, opts, module) do
    op = CommandModules.module_to_command(module)
    {:error, ExitCodes.exit_code_for(op, result),
     "Error: operation #{op} on node #{opts[:node]} timed out. Timeout value used: #{to}"}
  end
  defp format_error({:error, {:badrpc, {:timeout, to, warning}}}, opts, module) do
    op = CommandModules.module_to_command(module)
    {:error, ExitCodes.exit_code_for(op, {:timeout, to}),
     "Error: operation #{op} on node #{opts[:node]} timed out. Timeout value used: #{to}. #{warning}"}
  end
  defp format_error({:error, {:no_such_vhost, vhost} = result}, _opts, command) do
    {:error, ExitCodes.exit_code_for(command, result),
     "Virtual host '#{vhost}' does not exist"}
  end
  defp format_error({:error, {:timeout, to} = result}, opts, module) do
    op = CommandModules.module_to_command(module)
    {:error, ExitCodes.exit_code_for(op, result),
     "Error: operation #{op} on node #{opts[:node]} timed out. Timeout value used: #{to}"}
  end
  defp format_error({:error, :timeout = result}, opts, module) do
    op = CommandModules.module_to_command(module)
    {:error, ExitCodes.exit_code_for(op, result),
     "Error: operation #{op} on node #{opts[:node]} timed out. Timeout value used: #{opts[:timeout]}"}
  end
  defp format_error({:error, err} = result, _, command) do
    string_err = Helpers.string_or_inspect(err)
    {:error, ExitCodes.exit_code_for(command, result), "Error:\n#{string_err}"}
  end

  defp get_node_diagnostics(nil) do
    "Target node is not defined"
  end
  defp get_node_diagnostics(node_name) do
    to_string(:rabbit_nodes_common.diagnostics([node_name]))
  end

  defp badrpc_error_message_header(node, _opts) do
    """
    Error: unable to perform an operation on node '#{node}'. Please see diagnostics information and suggestions below.

    Most common reasons for this are:

     * Target node is unreachable (e.g. due to hostname resolution, TCP connection or firewall issues)
     * CLI tool fails to authenticate with the server (e.g. due to CLI tool's Erlang cookie not matching that of the server)
     * Target node is not running

    In addition to the diagnostics info below:

     * See the CLI, clustering and networking guides on http://rabbitmq.com/documentation.html to learn more
     * Consult server logs on node #{node}
    """
  end

  @spec with_distribution(options(), (() -> command_result())) :: command_result()
  defp with_distribution(options, code) do
    # Tries to start net_kernel distribution, and calls `code`
    # function on success. Otherswise returns error suitable for
    # handle_shutdown/0.
    case Distribution.start(options) do
      :ok      ->
        code.()
      {:ok, _} ->
        code.()
      {:error, reason} ->
        {:error, ExitCodes.exit_config, "Distribution failed: #{inspect reason}"}
    end
  end

end
