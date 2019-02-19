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

defmodule RabbitMQ.CLI.Ctl.Commands.VersionCommand do
  alias RabbitMQ.CLI.Core.Validators

  @behaviour RabbitMQ.CLI.CommandBehaviour

  def scopes(), do: [:ctl, :diagnostics, :plugins]

  use RabbitMQ.CLI.Core.MergesNoDefaults
  use RabbitMQ.CLI.Core.AcceptsNoPositionalArguments

  def validate_execution_environment([] = args, opts) do
    Validators.rabbit_is_loaded(args, opts)
  end

  def run([], %{formatter: "json"}) do
    {:ok, %{version: to_string(:rabbit_misc.version())}}
  end
  def run([], %{formatter: "csv"}) do
    row = [version: to_string(:rabbit_misc.version())]
    {:ok, [row]}
  end
  def run([], _opts) do
    {:ok, to_string(:rabbit_misc.version())}
  end
  use RabbitMQ.CLI.DefaultOutput

  def usage, do: "version"

  def banner(_, _), do: nil
end
