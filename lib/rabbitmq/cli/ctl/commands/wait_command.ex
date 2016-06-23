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


defmodule RabbitMQ.CLI.Ctl.Commands.WaitCommand do
  @behaviour RabbitMQ.CLI.CommandBehaviour
  @flags []

  def scopes(), do: [:ctl]

  def merge_defaults(args, opts), do: {args, opts}

  def validate([_|_] = args, _) when length(args) > 1, do: {:validation_failure, :too_many_args}
  def validate([], _), do: {:validation_failure, :not_enough_args}
  def validate([_], _), do: :ok

  def switches(), do: []

  def run([pid_file], %{node: node_name}) do
    wait_for_application(node_name, pid_file, :rabbit_and_plugins);
  end

  def usage, do: "wait <pid_file>"

  def flags, do: @flags

  def banner(_, %{node: node_name}), do: "Waiting for node #{node_name} ..."

  defp wait_for_application(node, pid_file, :rabbit_and_plugins) do
      case read_pid_file(pid_file, true) do
        {:error, _} = err -> err
        pid ->
          IO.puts "pid is #{pid}"
          wait_for_startup(node, pid)
      end
  end

  defp wait_for_startup(node, pid) do
    while_process_is_alive(
      node, pid, fn() -> :rpc.call(node, :rabbit, :await_startup, []) == :ok end)
  end

  defp while_process_is_alive(node, pid, activity) do
    case :rabbit_misc.is_os_process_alive(pid) do
      true  ->
        case activity.() do
          true  -> :ok
          false ->
            :timer.sleep(1000)
            while_process_is_alive(node, pid, activity)
        end
      false -> {:error, :process_not_running}
    end
  end

  defp read_pid_file(pid_file, wait) do
    case {:file.read_file(pid_file), wait} do
      {{:ok, bin}, _} ->
        case Integer.parse(bin) do
          :error ->
            {:error, {:garbage_in_pid_file, pid_file}}
          {int, _} -> Integer.to_char_list int
        end
      {{:error, :enoent}, true} ->
        :timer.sleep(1000)
        read_pid_file(pid_file, wait)
      {{:error, err}, _} ->
        {:error, {:could_not_read_pid, err}}
    end
  end

end
