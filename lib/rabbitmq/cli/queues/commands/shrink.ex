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

defmodule RabbitMQ.CLI.Queues.Commands.Shrink do
  import Rabbitmq.Atom.Coerce

  @behaviour RabbitMQ.CLI.CommandBehaviour

  def switches() do
    [errors_only: :boolean]
  end

  def merge_defaults(args, opts) do
    {args, Map.merge(%{errors_only: false}, opts)}
  end

  use RabbitMQ.CLI.Core.AcceptsOnePositionalArgument
  use RabbitMQ.CLI.Core.RequiresRabbitAppRunning

  def run([node], %{node: node_name,
                    errors_only: errs}) do
    case :rabbit_misc.rpc_call(node_name, :rabbit_quorum_queue, :shrink_all, [
           to_atom(node)
         ]) do
      results when errs ->
        for {{:resource, vhost, _kind, name}, {_errors, _, _} = res} <- results,
        do: [{:vhost, vhost},
             {:name, name},
             {:size, format_size res},
             {:result, format_result res}]
      results ->
        for {{:resource, vhost, _kind, name}, res} <- results,
        do: [{:vhost, vhost},
             {:name, name},
             {:size, format_size res},
             {:result, format_result res}]
    end
  end

  defp format_size({:ok, size}) do
    size
  end
  defp format_size({:error, _size, :timeout}) do
    # the actual size is uncertain here
    "?"
  end
  defp format_size({:error, size, _}) do
    size
  end

  defp format_result({:ok, _size}) do
    "ok"
  end
  defp format_result({:error, _size, :last_node}) do
    "error: the last node cannot be removed"
  end
  defp format_result({:error, _size, :timeout}) do
    "error: the operation timed out and may not have been completed"
  end
  defp format_result({:error, _size, err}) do
    :io.format "error: ~W", [err, 10]
  end


  use RabbitMQ.CLI.DefaultOutput

  def formatter(), do: RabbitMQ.CLI.Formatters.Table

  def banner([node], _) do
    "Shrinking queues on #{node}..."
  end

  def usage, do: "shrink <node>"
end
