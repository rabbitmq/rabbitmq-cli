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
##


defmodule ListChannelsCommand do
    @behaviour CommandBehaviour

    @info_keys ~w(pid connection name number user vhost transactional
                  confirm consumer_count messages_unacknowledged
                  messages_uncommitted acks_uncommitted messages_unconfirmed
                  prefetch_count global_prefetch_count)a

    def flags() do
        []
    end

    def usage() do
        "list_channels [<channelinfoitem> ...]"
    end

    def usage_additional() do
        "<channelinfoitem> must be a member of the list ["<>
        Enum.join(@info_keys, ", ") <>"]."
    end

    def run([], opts) do
        run(~w(pid user consumer_count messages_unacknowledged), opts)
    end
    def run([_|_] = args, %{node: node_name, timeout: timeout} = opts) do
        info_keys = Enum.map(args, &String.to_atom/1)
        InfoKeys.with_valid_info_keys(args, @info_keys,
            fn(info_keys) ->
                info(opts)
                node_name
                |> Helpers.parse_node
                |> RpcStream.receive_list_items(:rabbit_channel, :info_all,
                                                [info_keys],
                                                timeout,
                                                info_keys)
            end)
    end

    defp default_opts() do
        %{}
    end

    defp info(%{quiet: true}), do: nil
    defp info(_), do: IO.puts "Listing channels ..."
end