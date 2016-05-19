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


defmodule ListQueuesCommand do
    @behaviour CommandBehaviour

    @info_keys ~w(name durable auto_delete
              arguments policy pid owner_pid exclusive exclusive_consumer_pid
              exclusive_consumer_tag messages_ready messages_unacknowledged messages
              messages_ready_ram messages_unacknowledged_ram messages_ram
              messages_persistent message_bytes message_bytes_ready
              message_bytes_unacknowledged message_bytes_ram message_bytes_persistent
              head_message_timestamp disk_reads disk_writes consumers
              consumer_utilisation memory slave_pids synchronised_slave_pids state)a

    def flags() do
        [:param, :offline, :online]
    end

    def usage() do
        "list_queues [-p <vhost>] [--online] [--offline] [<queueinfoitem> ...]"
    end

    def usage_additional() do
        "<queueinfoitem> must be a member of the list ["<>
        Enum.join(@info_keys, ", ") <>"]."
    end

    def run([], opts) do
        run(~w(name messages), opts)
    end
    def run([_|_] = args, %{node: node_name, timeout: timeout, param: vhost,
                                    online: online_opt, offline: offline_opt} = opts) do
        {online, offline} = case {online_opt, offline_opt} do
            {false, false} -> {true, true};
            other          -> other
        end
        InfoKeys.with_valid_info_keys(args, @info_keys,
            fn(info_keys) ->
                info(opts)
                node_name
                |> Helpers.parse_node
                |> RpcStream.receive_list_items(:rabbit_amqqueue, :info_all,
                                                [vhost, info_keys, online, offline],
                                                timeout,
                                                info_keys)
            end)
    end
    def run([_|_] = args, opts) do
        run(args, Map.merge(default_opts, opts))
    end

    defp default_opts() do
        %{param: "/", offline: false, online: false}
    end

    defp info(%{quiet: true}), do: nil
    defp info(_), do: IO.puts "Listing queues ..."
end