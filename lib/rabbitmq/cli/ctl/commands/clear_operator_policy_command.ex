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


defmodule RabbitMQ.CLI.Ctl.Commands.ClearOperatorPolicyCommand do
  @behaviour RabbitMQ.CLI.CommandBehaviour
  use RabbitMQ.CLI.DefaultOutput
  alias RabbitMQ.CLI.Core.Helpers, as: Helpers

  def merge_defaults(args, opts) do
    {args, Map.merge(%{vhost: "/"}, opts)}
  end

  def validate([], _) do
    {:validation_failure, :not_enough_args}
  end
  def validate([_,_|_], _) do
    {:validation_failure, :too_many_args}
  end
  def validate([_], _), do: :ok

  def run([key], %{node: node_name, vhost: vhost}) do
    :rabbit_misc.rpc_call(node_name,
      :rabbit_policy, :delete_op, [vhost, key, Helpers.cli_acting_user()])
  end

  def usage, do: "clear_operator_policy [-p <vhost>] <key>"

  def banner([key], %{vhost: vhost}) do
    "Clearing operator policy \"#{key}\" on vhost \"#{vhost}\" ..."
  end
end
