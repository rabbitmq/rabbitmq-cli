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


defmodule RabbitMQ.CLI.Ctl.Commands.ReportCommand do
  alias RabbitMQ.CLI.Ctl.Commands.StatusCommand,          as: StatusCommand
  alias RabbitMQ.CLI.Ctl.Commands.ClusterStatusCommand,   as: ClusterStatusCommand
  alias RabbitMQ.CLI.Ctl.Commands.EnvironmentCommand,     as: EnvironmentCommand
  alias RabbitMQ.CLI.Ctl.Commands.ListConnectionsCommand, as: ListConnectionsCommand
  alias RabbitMQ.CLI.Ctl.Commands.ListChannelsCommand,    as: ListChannelsCommand
  alias RabbitMQ.CLI.Ctl.Commands.ListQueuesCommand,      as: ListQueuesCommand
  alias RabbitMQ.CLI.Ctl.Commands.ListExchangesCommand,   as: ListExchangesCommand
  alias RabbitMQ.CLI.Ctl.Commands.ListBindingsCommand,    as: ListBindingsCommand
  alias RabbitMQ.CLI.Ctl.Commands.ListPermissionsCommand, as: ListPermissionsCommand

  @behaviour RabbitMQ.CLI.CommandBehaviour
  @flags []

  def scopes(), do: [:ctl]

  def switches(), do: []
  def merge_defaults(args, opts), do: {args, opts}

  def validate([_|_] = args, _) when length(args) != 0, do: {:validation_failure, :too_many_args}
  def validate([], _), do: :ok

  defp merge_run(command, args, opts) do
    {args, opts} = command.merge_defaults(args, opts)
    command.run(args, opts)
  end


  def run([], %{node: node_name} = opts) do
    case :rabbit_misc.rpc_call(node_name, :rabbit_vhost, :list, []) do
      {:badrpc, _} = err ->
        err
      vhosts ->
        data =
          [ merge_run(StatusCommand, [], opts),

            merge_run(ClusterStatusCommand, [], opts),
            merge_run(EnvironmentCommand, [], opts),
            merge_run(ListConnectionsCommand, [], opts),
            merge_run(ListChannelsCommand, [], opts) ]

        vhost_data =
            vhosts
            |> Enum.flat_map(fn v ->
              opts = Map.put(opts, :vhost, v)
              [ merge_run(ListQueuesCommand, [], opts),
                merge_run(ListExchangesCommand, [], opts),
                merge_run(ListBindingsCommand, [], opts),
                merge_run(ListPermissionsCommand, [], opts) ]
            end)
        data ++ vhost_data
    end
  end

  def usage, do: "report"

  def flags, do: @flags

  def banner(_,%{node: node_name}), do: "Reporting server status of node #{node_name} ..."
end
