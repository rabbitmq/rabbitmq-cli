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

defmodule RabbitMQ.CLI.Diagnostics.Commands.ErlangVersionCommand do
  @behaviour RabbitMQ.CLI.CommandBehaviour

  def requires_rabbit_app_running?, do: false

  def merge_defaults(args, opts) do
    {args, Map.merge(%{details: false}, opts)}
  end

  def validate(args, _) when length(args) > 0 do
    {:validation_failure, :too_many_args}
  end
  def validate(_, _), do: :ok

  def switches(), do: [details: :boolean]

  def usage, do: "erlang_version"

  def run([], %{node: node_name, timeout: timeout, details: details}) do
    case details do
      true ->
        :rabbit_misc.rpc_call(node_name, :rabbit_misc, :otp_system_version, [], timeout)
      false ->
        :rabbit_misc.rpc_call(node_name, :rabbit_misc, :platform_and_version, [], timeout)
    end
  end

  def output(result, _options) when is_list(result) do
    {:ok, result}
  end
  use RabbitMQ.CLI.DefaultOutput

  def banner([], %{node: node_name}) do
    "Asking node #{node_name} for its Erlang/OTP version..."
  end

  def formatter(), do: RabbitMQ.CLI.Formatters.String
end
