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
## Copyright (c) 2007-2016 Pivotal Software, Inc.  All rights reserved.


defmodule RabbitMQCtl do
  alias RabbitMQ.CLI.Core.Distribution,  as: Distribution

  alias RabbitMQ.CLI.Ctl.Commands.HelpCommand, as: HelpCommand
  alias RabbitMQ.CLI.Core.Output, as: Output
  alias RabbitMQ.CLI.Core.ExitCodes, as: ExitCodes
  alias RabbitMQ.CLI.Core.CommandModules, as: CommandModules
  alias RabbitMQ.CLI.Core.Parser, as: Parser

  import RabbitMQ.CLI.Core.Helpers

  def main(["--auto-complete", "./rabbitmqctl " <> str]) do
    auto_complete(str)
  end
  def main(["--auto-complete", "rabbitmqctl " <> str]) do
    auto_complete(str)
  end
  def main(unparsed_command) do
    # we cannot depend on positional arguments being correct here
    # because Parser.parse_global/1 is unaware of command-specific switches. MK.
    {_parsed_positional_args, parsed_options, _} = Parser.parse_global(unparsed_command)
    global_options = parsed_options |> merge_all_defaults |> normalize_options
    CommandModules.load(global_options)

    case extract_command_name(unparsed_command) do
      :no_command ->
        {:error, ExitCodes.exit_usage, HelpCommand.all_usage()};
      {command_name, command} ->
        case Parser.parse_command_specific(command, unparsed_command) do
          {_, _, [_|_] = invalid} ->
            validation_error({:bad_option, invalid}, command_name, unparsed_command);
          {positional_args, command_options, []} ->
            # positional arguments also include command name, shift it. MK.
            [_command_name | arguments] = positional_args
            # merge normalized global options
            options = Map.merge(command_options, global_options)
            Distribution.start(options)

            case execute_command(command, arguments, options) do
              {:error, _, _} = err ->
                err;
              {:validation_failure, err} ->
                validation_error(err, command_name, unparsed_command);
              output  ->
                formatter = get_formatter(command, options)
                printer = get_printer(options)

                output
                |> Output.format_output(formatter, options)
                |> Output.print_output(printer, options)
            end
        end
    end
    |> handle_shutdown
  end

  defp extract_command_name([]) do
    :no_command
  end
  defp extract_command_name([command_name | _]) do
    case CommandModules.module_map[command_name] do
      nil                           -> :no_command;
      command when is_atom(command) -> {command_name, command}
    end
  end

  def handle_shutdown({:error, exit_code, output}) do
    output_device = case exit_code == ExitCodes.exit_ok do
      true  -> :stdio;
      false -> :stderr
    end
    for line <- List.flatten([output]) do
      IO.puts(output_device, line)
    end
    exit_program(exit_code)
  end
  def handle_shutdown(_) do
    exit_program(ExitCodes.exit_ok)
  end

  def auto_complete(str) do
    Rabbitmq.CLI.AutoComplete.complete(str)
    |> Stream.map(&IO.puts/1) |> Stream.run
    exit_program(ExitCodes.exit_ok)
  end

  def merge_all_defaults(%{} = options) do
    options
    |> merge_defaults_node
    |> merge_defaults_timeout
    |> merge_defaults_longnames
  end

  defp merge_defaults_node(%{} = opts), do: Map.merge(%{node: get_rabbit_hostname}, opts)

  defp merge_defaults_timeout(%{} = opts), do: Map.merge(%{timeout: :infinity}, opts)

  defp merge_defaults_longnames(%{} = opts), do: Map.merge(%{longnames: false}, opts)

  defp normalize_options(opts) do
    opts
    |> normalize_node
    |> normalize_timeout
  end

  defp normalize_node(%{node: node} = opts) do
    Map.merge(opts, %{node: parse_node(node)})
  end

  defp normalize_timeout(%{timeout: timeout} = opts)
  when is_integer(timeout) do
    Map.put(opts, :timeout, timeout * 1000)
  end
  defp normalize_timeout(opts) do
    opts
  end


  defp maybe_connect_to_rabbitmq(HelpCommand, _), do: nil
  defp maybe_connect_to_rabbitmq(_, node) do
    connect_to_rabbitmq(node)
  end

  defp execute_command(command, arguments, options) do
    {arguments, options} = command.merge_defaults(arguments, options)
    case command.validate(arguments, options) do
      :ok ->
        maybe_print_banner(command, arguments, options)
        maybe_connect_to_rabbitmq(command, options[:node])
        maybe_run_command(command, arguments, options)
      {:validation_failure, _} = err -> err
    end
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

  def get_printer(%{printer: printer}) do
    module_name = String.to_atom("RabbitMQ.CLI.Printers." <> Macro.camelize(printer))
    case Code.ensure_loaded(module_name) do
      {:module, _}      -> module_name;
      {:error, :nofile} -> default_printer
    end
  end
  def get_printer(_) do
    default_printer
  end

  def default_printer() do
    RabbitMQ.CLI.Printers.StdIO
  end

  def default_formatter(command) do
    case function_exported?(command, :formatter, 0) do
      true  -> command.formatter;
      false -> RabbitMQ.CLI.Formatters.Inspect
    end
  end

  ## Suppress banner if --quiet option is provided
  defp maybe_print_banner(_, _, %{quiet: true}) do
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

  defp validation_error(err_detail, command_name, unparsed_command) do
    err = format_validation_error(err_detail, command_name) # TODO format the error better
    base_error = "Error: #{err}\nGiven:\n\t#{unparsed_command |> Enum.join(" ")}"

    usage = case CommandModules.is_command?(command_name) do
      true  ->
        command = CommandModules.module_map[command_name]
        HelpCommand.base_usage(HelpCommand.program_name(), command)
      false ->
        HelpCommand.all_usage()
    end
    message = base_error <> "\n" <> usage
    {:error, ExitCodes.exit_code_for({:validation_failure, err_detail}), message}
  end

  defp format_validation_error(:not_enough_args, _), do: "not enough arguments."
  defp format_validation_error({:not_enough_args, detail}, _), do: "not enough arguments. #{detail}"
  defp format_validation_error(:too_many_args, _), do: "too many arguments."
  defp format_validation_error({:too_many_args, detail}, _), do: "too many arguments. #{detail}"
  defp format_validation_error(:bad_argument, _), do: "Bad argument."
  defp format_validation_error({:bad_argument, detail}, _), do: "Bad argument. #{detail}"
  defp format_validation_error({:bad_option, opts}, command_name) do
    header = case CommandModules.is_command?(command_name) do
      true  -> "Invalid options for this command:";
      false -> "Invalid options:"
    end
    Enum.join([header | for {key, val} <- opts do "#{key} : #{val}" end], "\n")
  end
  defp format_validation_error(err, _), do: inspect err

  defp exit_program(code) do
    :net_kernel.stop
    exit({:shutdown, code})
  end
end
