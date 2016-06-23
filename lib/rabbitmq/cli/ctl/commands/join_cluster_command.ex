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
## Copyright (c) 2016 Pivotal Software, Inc.  All rights reserved.


defmodule RabbitMQ.CLI.Ctl.Commands.JoinClusterCommand do
  alias RabbitMQ.CLI.Ctl.Helpers, as: Helpers

  @behaviour RabbitMQ.CLI.CommandBehaviour
  @flags [
    :disc, # --disc is accepted for consistency's sake.
    :ram
  ]

  def scopes(), do: [:ctl]

  def flags, do: @flags
  def switches() do
    [
      disc: :boolean,
      ram: :boolean
    ]
  end

  def merge_defaults(args, opts) do
    {args, Map.merge(%{disc: true, ram: false}, opts)}
  end

  def validate(_, %{disc: true, ram: true}) do
    {:validation_failure,
     {:bad_argument, "The node type must be either disc or ram."}}
  end
  def validate([], _),  do: {:validation_failure, :not_enough_args}
  def validate([_], _), do: :ok
  def validate(_, _),   do: {:validation_failure, :too_many_args}

  def run([target_node], %{node: node_name, ram: ram}) do
    node_type = case ram do
      true -> :ram
      _    -> :disc
    end
    ret = :rabbit_misc.rpc_call(node_name,
        :rabbit_mnesia,
        :join_cluster,
        [Helpers.parse_node(target_node), node_type]
      )
    case ret do
      {:error, reason} ->
        {:join_cluster_failed, {reason, node_name}}
      result ->
        result
    end
  end

  def usage() do
    "join_cluster [--disc|--ram] <existing_cluster_member_node>"
  end

  def banner([target_node], %{node: node_name}) do
    "Clustering node #{node_name} with #{target_node}"
  end
end
