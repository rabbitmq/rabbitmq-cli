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


defmodule RabbitMQ.CLI.Ctl.Commands.ClearPermissionsCommand do
  @behaviour RabbitMQ.CLI.CommandBehaviour
  @default_vhost "/"
  @flags [:vhost]

  def scopes(), do: [:ctl]

  def merge_defaults(args, opts), do: {args, opts}
  def validate([], _) do
    {:validation_failure, :not_enough_args}
  end
  def validate([_|_] = args, _) when length(args) > 1 do
    {:validation_failure, :too_many_args}
  end
  def validate([_], _), do: :ok

  def switches(), do: []

  def run([username], %{node: node_name, vhost: vhost}) do
    :rabbit_misc.rpc_call(node_name,
      :rabbit_auth_backend_internal, :clear_permissions, [username, vhost])
  end

  def run([username], %{node: _} = opts) do
    run([username], Map.merge(opts, %{vhost: @default_vhost}))
  end

  def usage, do: "clear_permissions [-p vhost] <username>"

  def banner([username], %{vhost: vhost}), do: "Clearing permissions for user \"#{username}\" in vhost \"#{vhost}\" ..."

  def flags, do: @flags
end
