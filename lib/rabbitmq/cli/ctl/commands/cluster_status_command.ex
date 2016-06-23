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


defmodule RabbitMQ.CLI.Ctl.Commands.ClusterStatusCommand do
  @behaviour RabbitMQ.CLI.CommandBehaviour
  @flags []

  def scopes(), do: [:ctl]

  def merge_defaults(args, opts), do: {args, opts}
  def switches(), do: []
  def validate(args, _) when length(args) != 0, do: {:validation_failure, :too_many_args}
  def validate([], _), do: :ok

  def run([], %{node: node_name}) do
    status = :rabbit_misc.rpc_call(node_name, :rabbit_mnesia, :status, [])
    case :rabbit_misc.rpc_call(node_name, :rabbit_mnesia, :cluster_nodes, [:running]) do
      {:badrpc, _} = err ->
        err
      nodes ->
        alarms_by_node = Enum.map(nodes, &alarms_by_node/1)
        status ++ [{:alarms, alarms_by_node}]
    end
  end

  def usage, do: "cluster_status"

  def flags, do: @flags

  defp alarms_by_node(node) do
    status = :rabbit_misc.rpc_call(node, :rabbit, :status, [])
    {node, List.keyfind(status, :alarms, 1, [])}
  end

  def banner(_, %{node: node_name}), do: "Cluster status of node #{node_name} ..."
end
