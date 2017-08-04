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

defmodule RabbitMQ.CLI.Ctl.Commands.ListQueuesCommand do
  @behaviour RabbitMQ.CLI.CommandBehaviour
  require RabbitMQ.CLI.Ctl.InfoKeys
  require RabbitMQ.CLI.Ctl.RpcStream

  use RabbitMQ.CLI.DefaultOutput

  alias RabbitMQ.CLI.Ctl.InfoKeys, as: InfoKeys
  alias RabbitMQ.CLI.Ctl.RpcStream, as: RpcStream
  alias RabbitMQ.CLI.Core.Helpers, as: Helpers

  def formatter(), do: RabbitMQ.CLI.Formatters.Table

  @info_keys ~w(name durable auto_delete
            arguments policy pid owner_pid exclusive exclusive_consumer_pid
            exclusive_consumer_tag messages_ready messages_unacknowledged messages
            messages_ready_ram messages_unacknowledged_ram messages_ram
            messages_persistent message_bytes message_bytes_ready
            message_bytes_unacknowledged message_bytes_ram message_bytes_persistent
            head_message_timestamp disk_reads disk_writes consumers
            consumer_utilisation memory slave_pids synchronised_slave_pids state)a

  def info_keys(), do: @info_keys

  def scopes(), do: [:ctl, :diagnostics]

  def validate(args, _opts) do
      case InfoKeys.validate_info_keys(args, @info_keys) do
        {:ok, _} -> :ok
        err -> err
      end
  end
  def merge_defaults([_|_] = args, opts) do
    {args, Map.merge(default_opts(), opts)}
  end
  def merge_defaults([], opts) do
      merge_defaults(~w(name messages), opts)
  end

  def switches(), do: [offline: :boolean, online: :boolean, local: :boolean]

  def usage() do
      "list_queues [-p <vhost>] [--online] [--offline] [--local] [<queueinfoitem> ...]"
  end

  def usage_additional() do
      "<queueinfoitem> must be a member of the list [" <>
      Enum.join(@info_keys, ", ") <> "]."
  end

  def run([_|_] = args, %{node: node_name, timeout: timeout, vhost: vhost,
                          online: online_opt, offline: offline_opt,
                          local: local_opt}) do
      {online, offline} = case {online_opt, offline_opt} do
        {false, false} -> {true, true};
        other          -> other
      end
      info_keys = InfoKeys.prepare_info_keys(args)
      Helpers.with_nodes_in_cluster(node_name, fn(nodes) ->
        offline_mfa = {:rabbit_amqqueue, :emit_info_down, [vhost, info_keys]}
        local_mfa = {:rabbit_amqqueue, :emit_info_local, [vhost, info_keys]}
        online_mfa  = {:rabbit_amqqueue, :emit_info_all, [nodes, vhost, info_keys]}
        {chunks, mfas} = case {local_opt, offline, online} do
          # Local takes precedence
          {true, _, _}      -> {1, [local_mfa]};
          {_, true, true}   -> {Kernel.length(nodes) + 1, [offline_mfa, online_mfa]};
          {_, false, true}  -> {Kernel.length(nodes), [online_mfa]};
          {_, true, false}  -> {1, [offline_mfa]}
        end
        RpcStream.receive_list_items(node_name, mfas, timeout, info_keys, chunks)
      end)
  end

  defp default_opts() do
    %{vhost: "/", offline: false, online: false, local: false}
  end

  def banner(_,%{vhost: vhost}), do: "Listing queues for vhost #{vhost} ..."
end
