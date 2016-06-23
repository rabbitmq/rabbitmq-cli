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


defmodule RabbitMQ.CLI.Ctl.Commands.SetPermissionsCommand do
  @behaviour RabbitMQ.CLI.CommandBehaviour
  @flags [:vhost]

  def scopes(), do: [:ctl]
  def merge_defaults(args, opts), do: {args, opts}

  def switches(), do: []
  def validate([], _) do
    {:validation_failure, :not_enough_args}
  end

  def validate([_|_] = args, _) when length(args) < 4 do
    {:validation_failure, :not_enough_args}
  end

  def validate([_|_] = args, _) when length(args) > 4 do
    {:validation_failure, :too_many_args}
  end
  def validate(_, _), do: :ok

  def run([user, conf, write, read], %{node: node_name, vhost: vhost}) do
    :rabbit_misc.rpc_call(node_name,
      :rabbit_auth_backend_internal,
      :set_permissions,
      [user, vhost, conf, write, read]
    )
  end

  def run([_, _, _, _] = args, %{node: _} = opts) do
    default_opts = Map.merge(opts, %{vhost: "/"})
    run(args, default_opts)
  end

  def usage, do: "set_permissions [-p <vhost>] <user> <conf> <write> <read>"

  def flags, do: @flags

  def banner([user|_], %{vhost: vhost}), do: "Setting permissions for user \"#{user}\" in vhost \"#{vhost}\" ..."
end
