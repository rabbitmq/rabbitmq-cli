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
## Copyright (c) 2007-2019 Pivotal Software, Inc.  All rights reserved.

defmodule RabbitMQ.CLI.Ctl.Commands.CommonOptionsCommand do
  alias RabbitMQ.CLI.Core.ExitCodes

  @behaviour RabbitMQ.CLI.CommandBehaviour

  def scopes(), do: [:ctl, :diagnostics, :plugins]

  def distribution(_), do: :none
  use RabbitMQ.CLI.Core.MergesNoDefaults

  def validate(_, _), do: :ok

  def run(_, _opts) do
    "\n" <> common_options_str()
  end

  def output(result, _) do
    {:error, ExitCodes.exit_ok(), result}
  end

  def banner(_, _), do: nil

  def help_section(), do: :help

  def description(), do: "Displays common options for commands"

  def usage() do
    "common_options\n\n" <> common_options_str()
  end

  def common_options_str() do
    """
    ## Common Options

    The following options are accepted by most or all commands.

    short            | long          | description
    -----------------|---------------|--------------------------------
    -?               | --help        | displays command help
    -n <node>        | --node <node> | connect to node <node>
    -l               | --longnames   | use long host names
    -t               | --timeout <n> | for commands that support it, operation timeout in seconds
    -q               | --quiet       | suppress informational messages
    -s               | --silent      | suppress informational messages
                                     | and table header row
    -p               | --vhost       | for commands that are scoped to a virtual host,
                     |               | virtual host to use
                     | --formatter   | alternative result formatter to use
                                     | if supported: json, pretty_table, table, csv",

    ## Target Node Name

    Default node is "rabbit@hostname", where `hostname` is the target node's hostname.
    On a host named "eng.example.com", the node name of the RabbitMQ node will
    usually be rabbit@eng. Node name can be overridden using the RABBITMQ_NODENAME environment
    variable at node startup time. The output of hostname -s is usually
    the correct suffix to use after the "@" sign. See rabbitmq-server(8)
    and RabbitMQ configuration and networking guides to learn more.

    If target RabbitMQ node is configured to use long node names, the "--longnames"
    option must be specified.

    ## Disabling Options

    Most options have a corresponding "long option" i.e. "-q" or "--quiet".
    Long options for boolean values may be negated with the "--no-" prefix,
    i.e. "--no-quiet" or "--no-table-headers"
    """
  end
end
