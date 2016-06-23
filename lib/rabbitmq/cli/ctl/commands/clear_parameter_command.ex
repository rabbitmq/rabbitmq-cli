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


defmodule RabbitMQ.CLI.Ctl.Commands.ClearParameterCommand do
  @behaviour RabbitMQ.CLI.CommandBehaviour
  @flags [:vhost]

  def scopes(), do: [:ctl]

  def switches(), do: []
  def merge_defaults(args, opts) do
    default_opts = Map.merge(opts, %{vhost: "/"})
    {args, default_opts}
  end

  def validate(args, _) when is_list(args) and length(args) < 2 do
    {:validation_failure, :not_enough_args}
  end
  def validate([_|_] = args, _) when length(args) > 2 do
    {:validation_failure, :too_many_args}
  end
  def validate([_,_], _), do: :ok

  def run([component_name, key], %{node: node_name, vhost: vhost}) do
    :rabbit_misc.rpc_call(node_name,
      :rabbit_runtime_parameters,
      :clear,
      [vhost, component_name, key])
  end

  def usage, do: "clear_parameter [-p <vhost>] <component_name> <key>"

  def flags, do: @flags

  def banner([component_name, key], %{vhost: vhost}) do
    "Clearing runtime parameter \"#{key}\" for component \"#{component_name}\" on vhost \"#{vhost}\" ..."
  end
end
