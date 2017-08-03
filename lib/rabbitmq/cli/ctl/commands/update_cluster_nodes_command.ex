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
## The Initial Developer of the Original Code is Pivotal Software, Inc.
## Copyright (c) 2016-2017 Pivotal Software, Inc.  All rights reserved.

defmodule RabbitMQ.CLI.Ctl.Commands.UpdateClusterNodesCommand do
  alias RabbitMQ.CLI.Core.Helpers, as: Helpers

  @behaviour RabbitMQ.CLI.CommandBehaviour

  def requires_rabbit_app_running?, do: false

  def merge_defaults(args, opts) do
    {args, opts}
  end

  def validate([], _),  do: {:validation_failure, :not_enough_args}
  def validate([_], _), do: :ok
  def validate(_, _),   do: {:validation_failure, :too_many_args}

  def run([seed_node], %{node: node_name}) do
    :rabbit_misc.rpc_call(node_name,
        :rabbit_mnesia,
        :update_cluster_nodes,
        [Helpers.parse_node(seed_node)]
      )
  end

  def usage() do
    "update_cluster_nodes <existing_cluster_member_node_to_seed_from>"
  end

  def banner([seed_node], %{node: node_name}) do
    "Will seed #{node_name} from #{seed_node} on next start"
  end

  def output({:error, :mnesia_unexpectedly_running}, %{node: node_name}) do
    {:error, RabbitMQ.CLI.Core.ExitCodes.exit_software,
     RabbitMQ.CLI.DefaultOutput.mnesia_running_error(node_name)}
  end
  def output({:error, :cannot_cluster_node_with_itself}, %{node: node_name}) do
    {:error, RabbitMQ.CLI.Core.ExitCodes.exit_software,
     "Error: cannot cluster node with itself: #{node_name}"}
  end
  use RabbitMQ.CLI.DefaultOutput
end
